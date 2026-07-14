import Foundation
import LiveReloadCore
import Observation

struct ProjectMutationGate {
    private var activeProjectIDs: Set<UUID> = []

    mutating func begin(_ projectID: UUID) -> Bool {
        activeProjectIDs.insert(projectID).inserted
    }

    mutating func end(_ projectID: UUID) {
        activeProjectIDs.remove(projectID)
    }

    func contains(_ projectID: UUID) -> Bool {
        activeProjectIDs.contains(projectID)
    }
}

enum ConfigurationStoreState: Equatable {
    case writable
    case sourceRecoveryRequired
    case newerVersion(Int)
    case unavailable
}

@MainActor
@Observable
final class AppModel {
    private(set) var isLoading: Bool
    private(set) var isAddingProject = false
    private(set) var projects: [ProjectConfiguration] = []
    private(set) var activities: [ActivityEvent] = []
    private(set) var configurationStoreState: ConfigurationStoreState
    private(set) var projectRuntimeProjections: [UUID: ProjectRuntimeProjection] = [:]
    private(set) var serverState: ServerState = .stopped
    private(set) var isServerOperationPending = false
    var selectedProjectID: UUID?
    var recoveryMessage: String?

    private let store: ProjectStore?
    private let activityStore: ActivityStore
    private let provider: any FolderAccessProvider
    private let accessCoordinator: ProjectAccessCoordinator?
    private let beforeProjectMutation: @Sendable (UUID) async -> Void
    private let runtimeService: any ReloadLoopRuntimeServing
    private let usesUITestRuntimeFixtures: Bool
    private var projectMutationGate = ProjectMutationGate()
    private var runtimeOperationGate = ProjectMutationGate()
    @ObservationIgnored private var runtimeUpdatesTask: Task<Void, Never>?

    convenience init() {
        self.init(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    convenience init(
        arguments: [String],
        environment: [String: String],
        automaticallyLoad: Bool = true,
        storeURLResolver: () throws -> URL = { try ProjectStore.applicationSupportURL() }
    ) {
        let isUITesting = arguments.contains { $0.hasPrefix("--ui-testing-") }
        if isUITesting, let testStorePath = environment["LIVERELOAD_UI_TEST_STORE"] {
            let url = URL(fileURLWithPath: testStorePath)
            self.init(
                store: ProjectStore(fileURL: url),
                provider: FakeFolderAccessProvider(),
                automaticallyLoad: automaticallyLoad,
                arguments: arguments,
                corruptionFixtureURL: url
            )
            return
        }

        do {
            let url = try storeURLResolver()
            self.init(
                store: ProjectStore(fileURL: url),
                provider: SecurityScopedBookmarkProvider(),
                automaticallyLoad: automaticallyLoad,
                arguments: arguments,
                corruptionFixtureURL: url
            )
        } catch {
            self.init(
                store: nil,
                provider: SecurityScopedBookmarkProvider(),
                automaticallyLoad: false,
                initialConfigurationStoreState: .unavailable
            )
        }
    }

    init(
        store: ProjectStore?,
        provider: any FolderAccessProvider,
        automaticallyLoad: Bool = true,
        arguments: [String] = [],
        corruptionFixtureURL: URL? = nil,
        initialConfigurationStoreState: ConfigurationStoreState = .writable,
        beforeProjectMutation: @escaping @Sendable (UUID) async -> Void = { _ in },
        runtimeService: (any ReloadLoopRuntimeServing)? = nil
    ) {
        let initialActivities: [ActivityEvent]
        if initialConfigurationStoreState == .unavailable {
            initialActivities = [ActivityEvent(
                category: .storage,
                severity: .error,
                summary: "Configuration storage is unavailable. Restore Application Support access and relaunch."
            )]
        } else {
            initialActivities = []
        }
        self.store = store
        self.provider = provider
        isLoading = automaticallyLoad
        configurationStoreState = initialConfigurationStoreState
        activities = initialActivities
        activityStore = ActivityStore(initialEvents: initialActivities)
        accessCoordinator = store.map { ProjectAccessCoordinator(store: $0, provider: provider) }
        self.beforeProjectMutation = beforeProjectMutation
        self.runtimeService = runtimeService ?? LiveReloadLoopRuntimeService(provider: provider)
        usesUITestRuntimeFixtures = arguments.contains {
            $0.hasPrefix("--ui-testing-monitoring-") ||
                $0.hasPrefix("--ui-testing-server-") ||
                $0 == "--ui-testing-activity-overflow"
        }
        initialActivities.forEach(AppLogger.log)
        observeRuntimeUpdates()
        guard automaticallyLoad else { return }
        Task {
            if arguments.contains("--ui-testing-delay-load") {
                try? await Task.sleep(for: .seconds(3))
            }
            if arguments.contains("--ui-testing-corrupt"), let corruptionFixtureURL {
                try? Data("not-json".utf8).write(to: corruptionFixtureURL)
            }
            await load()
            if arguments.contains("--ui-testing-seeded") {
                await seedUITestProject(state: .available)
            } else if arguments.contains("--ui-testing-repair") {
                await seedUITestProject(state: .missing)
            } else if arguments.contains("--ui-testing-long-label") {
                await seedUITestProject(
                    state: .available,
                    displayName: String(repeating: "Long Project Name ", count: 7)
                )
            }
            configureUITestRuntime(arguments: arguments)
            if !arguments.contains(where: { $0.hasPrefix("--ui-testing-") }) {
                await startLocalServer()
            }
            isLoading = false
        }
    }

    deinit {
        runtimeUpdatesTask?.cancel()
    }

    var selectedProject: ProjectConfiguration? {
        projects.first { $0.id == selectedProjectID }
    }

    var canMutateProjects: Bool {
        configurationStoreState == .writable
    }

    var connectedClientCount: Int { serverState.clientCount }

    func runtimeProjection(for projectID: UUID) -> ProjectRuntimeProjection {
        projectRuntimeProjections[projectID, default: .stopped]
    }

    func canManuallyReload(_ projectID: UUID) -> Bool {
        runtimeProjection(for: projectID).monitoringState == .watching &&
            serverState.phase == .listening &&
            serverState.clientCount > 0 &&
            !isRuntimeOperationPending(projectID)
    }

    func isProjectMutationPending(_ projectID: UUID) -> Bool {
        projectMutationGate.contains(projectID)
    }

    func isRuntimeOperationPending(_ projectID: UUID) -> Bool {
        runtimeOperationGate.contains(projectID)
    }

    func load() async {
        guard let store else {
            configurationStoreState = .unavailable
            projects = []
            selectedProjectID = nil
            isLoading = false
            return
        }
        do {
            var shouldRefreshAccess = false
            switch try await store.load() {
            case .loaded(let envelope), .empty(let envelope):
                configurationStoreState = .writable
                projects = envelope.projects
                shouldRefreshAccess = !projects.isEmpty
            case .recoveredFromCorruption(let envelope):
                configurationStoreState = .writable
                projects = envelope.projects
                await presentRecovery(
                    "Configuration was reset safely. The unreadable file was preserved for diagnosis.",
                    severity: .warning
                )
            case .recoveryRequired(let envelope):
                configurationStoreState = .sourceRecoveryRequired
                projects = envelope.projects
                await record(
                    .storage,
                    .error,
                    "Configuration could not be read and remains unchanged. Restore storage access and relaunch before changing projects.",
                )
            case .unsupportedFutureVersion(let version):
                configurationStoreState = .newerVersion(version)
                projects = []
                await record(
                    .storage,
                    .error,
                    "This configuration was created by a newer version and was preserved unchanged.",
                )
            }
            if shouldRefreshAccess {
                await refreshRestoredAccess()
            }
            if selectedProjectID == nil || !projects.contains(where: { $0.id == selectedProjectID }) {
                selectedProjectID = projects.first?.id
            }
        } catch {
            configurationStoreState = .sourceRecoveryRequired
            projects = []
            selectedProjectID = nil
            await record(
                .storage,
                .error,
                "Projects could not be loaded. Your configuration was preserved; retry or restore it.",
            )
        }
    }

    func addProject() async {
        guard canMutateProjects, let store, !isAddingProject else { return }
        isAddingProject = true
        defer { isAddingProject = false }
        guard let url = FolderPicker.chooseFolder() else { return }
        do {
            let reference = try await provider.createReference(for: url)
            let project = try ProjectConfiguration(displayName: url.lastPathComponent, folderReference: reference)
            projects = try await store.add(project).projects
            selectedProjectID = project.id
            await record(.folderAccess, .info, "Project access added.", projectID: project.id)
        } catch ProjectStoreError.duplicateFolderIdentity {
            await presentRecovery(
                "That folder is already configured. The existing project was preserved.",
                category: .folderAccess,
                severity: .warning
            )
        } catch {
            await presentRecovery(
                "The project could not be added. No existing configuration was changed.",
                severity: .error
            )
        }
    }

    func rename(_ project: ProjectConfiguration, to name: String) async {
        guard canMutateProjects, let store, beginMutation(for: project.id) else { return }
        defer { endMutation(for: project.id) }
        await beforeProjectMutation(project.id)
        do {
            projects = try await store.rename(projectID: project.id, to: name).projects
        } catch {
            await presentRecovery(
                "The name was not changed. Enter a name between 1 and 120 characters.",
                severity: .warning
            )
        }
    }

    func setEnabled(_ project: ProjectConfiguration, enabled: Bool) async {
        guard canMutateProjects, let store, beginMutation(for: project.id) else { return }
        defer { endMutation(for: project.id) }
        await beforeProjectMutation(project.id)
        if !enabled {
            applyProjectProjection(
                await runtimeService.stopMonitoring(projectID: project.id),
                projectID: project.id
            )
        }
        do {
            projects = try await store.setEnabled(projectID: project.id, enabled: enabled).projects
        } catch {
            await presentRecovery(
                "The setting could not be saved. The previous value was preserved.",
                severity: .error
            )
        }
    }

    func repair(_ project: ProjectConfiguration) async {
        guard canMutateProjects, let store, beginMutation(for: project.id) else { return }
        defer { endMutation(for: project.id) }
        await beforeProjectMutation(project.id)
        applyProjectProjection(
            await runtimeService.stopMonitoring(projectID: project.id),
            projectID: project.id
        )
        guard let url = FolderPicker.chooseFolder(prompt: "Repair Project Access") else { return }
        do {
            let reference = try await provider.repair(project.folderReference, with: url)
            projects = try await store.replaceFolderAccess(projectID: project.id, reference: reference).projects
            await record(.folderAccess, .info, "Project access repaired.", projectID: project.id)
        } catch {
            await presentRecovery(
                "Access was not repaired. The project and its settings were preserved.",
                category: .folderAccess,
                severity: .error
            )
        }
    }

    func remove(_ project: ProjectConfiguration) async {
        guard canMutateProjects, let store, beginMutation(for: project.id) else { return }
        defer { endMutation(for: project.id) }
        await beforeProjectMutation(project.id)
        applyProjectProjection(
            await runtimeService.stopMonitoring(projectID: project.id),
            projectID: project.id
        )
        do {
            projects = try await store.remove(projectID: project.id).projects
            projectRuntimeProjections[project.id] = nil
            if selectedProjectID == project.id { selectedProjectID = projects.first?.id }
            await record(.app, .info, "Project configuration removed; source files were not changed.")
        } catch {
            await presentRecovery(
                "The project could not be removed. Its configuration was preserved.",
                severity: .error
            )
        }
    }

    func startMonitoring(_ project: ProjectConfiguration) async {
        guard project.isEnabled,
              project.folderAccessState == .available,
              beginRuntimeOperation(for: project.id) else { return }
        defer { endRuntimeOperation(for: project.id) }
        let previous = runtimeProjection(for: project.id)
        applyProjectProjection(previous.replacingState(.starting), projectID: project.id)
        if usesUITestRuntimeFixtures {
            applyProjectProjection(previous.replacingState(.watching), projectID: project.id)
            return
        }
        let projection = await runtimeService.startMonitoring(project)
        applyProjectProjection(projection, projectID: project.id)
        if projection.monitoringState == .failed {
            await presentRecovery(
                monitoringFailureMessage(for: projection.recoveryReason),
                category: .monitoring,
                severity: .error
            )
        }
    }

    func stopMonitoring(_ project: ProjectConfiguration) async {
        guard beginRuntimeOperation(for: project.id) else { return }
        defer { endRuntimeOperation(for: project.id) }
        let current = runtimeProjection(for: project.id)
        applyProjectProjection(current.replacingState(.stopping), projectID: project.id)
        if usesUITestRuntimeFixtures {
            applyProjectProjection(.stopped, projectID: project.id)
            return
        }
        let projection = await runtimeService.stopMonitoring(projectID: project.id)
        applyProjectProjection(projection, projectID: project.id)
    }

    func retryMonitoring(_ project: ProjectConfiguration) async {
        guard project.isEnabled,
              project.folderAccessState == .available,
              beginRuntimeOperation(for: project.id) else { return }
        defer { endRuntimeOperation(for: project.id) }
        let previous = runtimeProjection(for: project.id)
        applyProjectProjection(previous.replacingState(.starting), projectID: project.id)
        if usesUITestRuntimeFixtures {
            applyProjectProjection(previous.replacingState(.watching), projectID: project.id)
            return
        }
        let projection = await runtimeService.retryMonitoring(project)
        applyProjectProjection(projection, projectID: project.id)
        if projection.monitoringState == .failed {
            await presentRecovery(
                monitoringFailureMessage(for: projection.recoveryReason),
                category: .monitoring,
                severity: .error
            )
        }
    }

    func manualReload(_ project: ProjectConfiguration) async {
        guard canManuallyReload(project.id), beginRuntimeOperation(for: project.id) else { return }
        defer { endRuntimeOperation(for: project.id) }
        if usesUITestRuntimeFixtures {
            let count = connectedClientCount
            let summary = count == 1
                ? "Manual reload sent to one browser."
                : "Manual reload sent to \(count) browsers."
            await record(.pipeline, .info, summary, projectID: project.id)
            return
        }
        guard let result = await runtimeService.manualReload(projectID: project.id) else { return }
        let summary = result.sentCount == 1
            ? "Manual reload sent to one browser."
            : "Manual reload sent to \(result.sentCount) browsers."
        await record(.pipeline, result.failedCount == 0 ? .info : .warning, summary, projectID: project.id)
    }

    func startLocalServer() async {
        guard !isServerOperationPending else { return }
        isServerOperationPending = true
        defer { isServerOperationPending = false }
        serverState = .starting
        if usesUITestRuntimeFixtures {
            serverState = uiTestListeningState(clientCount: 0)
            return
        }
        serverState = await runtimeService.startServer()
        if serverState.phase == .portConflict {
            await presentRecovery(
                "The local reload port is already in use. Monitoring is unchanged; close the conflicting service and retry.",
                category: .network,
                severity: .warning
            )
        } else if serverState.phase == .failed {
            await presentRecovery(
                "The local reload server could not start. Monitoring is unchanged and can be retried safely.",
                category: .network,
                severity: .error
            )
        }
    }

    func retryLocalServer() async {
        await startLocalServer()
    }

    private func refreshRestoredAccess() async {
        guard let accessCoordinator, let store else { return }
        for project in projects {
            do {
                let state = try await accessCoordinator.refreshAccess(for: project.id)
                guard state != .available else { continue }
                await record(
                    .folderAccess,
                    .warning,
                    "Saved folder access needs attention. Repair the project to continue.",
                    projectID: project.id
                )
            } catch {
                await record(
                    .folderAccess,
                    .error,
                    "Saved folder access could not be verified. The project was preserved.",
                    projectID: project.id
                )
            }
        }
        if let snapshot = try? await store.snapshot() {
            projects = snapshot.projects
        }
    }

    private func beginMutation(for projectID: UUID) -> Bool {
        guard !runtimeOperationGate.contains(projectID) else { return false }
        return projectMutationGate.begin(projectID)
    }

    private func endMutation(for projectID: UUID) {
        projectMutationGate.end(projectID)
    }

    private func beginRuntimeOperation(for projectID: UUID) -> Bool {
        guard !projectMutationGate.contains(projectID) else { return false }
        return runtimeOperationGate.begin(projectID)
    }

    private func endRuntimeOperation(for projectID: UUID) {
        runtimeOperationGate.end(projectID)
    }

    private func observeRuntimeUpdates() {
        let runtimeService = runtimeService
        runtimeUpdatesTask = Task { [weak self] in
            let updates = await runtimeService.updates()
            for await update in updates {
                guard !Task.isCancelled, let self else { return }
                switch update {
                case .project(let projectID, let projection):
                    applyProjectProjection(projection, projectID: projectID)
                case .server(let state):
                    serverState = state
                }
            }
        }
    }

    private func applyProjectProjection(
        _ projection: ProjectRuntimeProjection,
        projectID: UUID
    ) {
        projectRuntimeProjections[projectID] = projection
    }

    private func monitoringFailureMessage(
        for reason: MonitoringRecoveryReason?
    ) -> String {
        switch reason {
        case .folderUnavailable:
            "Monitoring could not start because folder access is unavailable. Repair access and retry."
        case .rootChanged:
            "Monitoring stopped because the project root changed. Repair access and retry."
        case .eventsDropped, .scanRequired:
            "Monitoring paused after the file event stream became incomplete. Retry to create a fresh session."
        case .sourceFailure, nil:
            "Monitoring could not start safely. The project configuration was preserved; retry when ready."
        }
    }

    private func presentRecovery(
        _ message: String,
        category: ActivityCategory = .storage,
        severity: ActivitySeverity
    ) async {
        recoveryMessage = message
        await record(category, severity, message)
    }

    private func record(
        _ category: ActivityCategory,
        _ severity: ActivitySeverity,
        _ summary: String,
        projectID: UUID? = nil
    ) async {
        let event = ActivityEvent(category: category, severity: severity, summary: summary, projectID: projectID)
        await activityStore.append(event)
        activities = await activityStore.snapshot()
        AppLogger.log(event)
    }

    private func seedUITestProject(
        state: FolderAccessState,
        displayName: String = "Fixture Project"
    ) async {
        guard canMutateProjects, let store, projects.isEmpty else { return }
        do {
            let reference = try FolderReference(
                bookmarkData: Data("synthetic-ui-test-bookmark".utf8),
                normalizedIdentity: "synthetic-ui-test-project",
                displayLabel: "Disposable Fixture"
            )
            let project = try ProjectConfiguration(
                displayName: String(displayName.prefix(120)),
                folderReference: reference,
                folderAccessState: state
            )
            projects = try await store.add(project).projects
            selectedProjectID = project.id
        } catch {
            recoveryMessage = "The synthetic UI test project could not be created."
        }
    }

    private func configureUITestRuntime(arguments: [String]) {
        guard usesUITestRuntimeFixtures, let project = selectedProject else { return }

        var projection = ProjectRuntimeProjection.stopped
        if arguments.contains("--ui-testing-monitoring-starting") {
            projection = projection.replacingState(.starting)
        } else if arguments.contains("--ui-testing-monitoring-watching") {
            projection = projection.replacingState(.watching)
        } else if arguments.contains("--ui-testing-monitoring-recovering") {
            projection = projection.replacingState(.recovering, reason: .eventsDropped)
        } else if arguments.contains("--ui-testing-monitoring-failed") {
            projection = projection.replacingState(.failed, reason: .sourceFailure)
        } else if arguments.contains("--ui-testing-monitoring-folder-unavailable") {
            projection = projection.replacingState(.failed, reason: .folderUnavailable)
        }

        if arguments.contains("--ui-testing-server-starting") {
            serverState = .starting
        } else if arguments.contains("--ui-testing-server-port-conflict") {
            serverState = .portConflict
            projection = projection.replacingState(.watching)
        } else if arguments.contains("--ui-testing-server-listening") ||
                    arguments.contains("--ui-testing-server-no-clients") {
            serverState = uiTestListeningState(clientCount: 0)
            projection = projection.replacingState(.watching)
        } else if arguments.contains("--ui-testing-server-two-clients") {
            serverState = uiTestListeningState(clientCount: 2)
            projection = projection.replacingState(.watching)
        }

        if arguments.contains("--ui-testing-activity-overflow") {
            let paths = [
                "Styles/\(String(repeating: "nested-component-", count: 12))site.css",
            ] + (1...11).map { "Sources/Feature\($0)/component-\($0).js" }
            if let batch = try? ChangeBatch(
                projectID: project.id,
                relativePaths: paths,
                classification: .fullPage
            ) {
                projection = ProjectRuntimeProjection(
                    monitoringState: .watching,
                    recoveryReason: nil,
                    lastSafeBatch: batch
                )
            }
        }

        applyProjectProjection(projection, projectID: project.id)
    }

    private func uiTestListeningState(clientCount: Int) -> ServerState {
        (try? ServerState.listening(clientCount: clientCount)) ?? .failed
    }
}
