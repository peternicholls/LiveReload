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

@MainActor
@Observable
final class AppModel {
    private(set) var isLoading = true
    private(set) var isAddingProject = false
    private(set) var projects: [ProjectConfiguration] = []
    private(set) var activities: [ActivityEvent] = []
    var selectedProjectID: UUID?
    var recoveryMessage: String?

    private let store: ProjectStore
    private let activityStore = ActivityStore()
    private let provider: any FolderAccessProvider
    private let accessCoordinator: ProjectAccessCoordinator
    private var projectMutationGate = ProjectMutationGate()

    convenience init() {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let isUITesting = arguments.contains { $0.hasPrefix("--ui-testing-") }
        let url: URL
        let provider: any FolderAccessProvider
        if isUITesting, let testStorePath = environment["LIVERELOAD_UI_TEST_STORE"] {
            url = URL(fileURLWithPath: testStorePath)
            provider = FakeFolderAccessProvider()
        } else {
            url = try! ProjectStore.applicationSupportURL()
            provider = SecurityScopedBookmarkProvider()
        }
        self.init(
            store: ProjectStore(fileURL: url),
            provider: provider,
            arguments: arguments,
            corruptionFixtureURL: url
        )
    }

    init(
        store: ProjectStore,
        provider: any FolderAccessProvider,
        automaticallyLoad: Bool = true,
        arguments: [String] = [],
        corruptionFixtureURL: URL? = nil
    ) {
        self.store = store
        self.provider = provider
        accessCoordinator = ProjectAccessCoordinator(store: store, provider: provider)
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
            isLoading = false
        }
    }

    var selectedProject: ProjectConfiguration? {
        projects.first { $0.id == selectedProjectID }
    }

    func isProjectMutationPending(_ projectID: UUID) -> Bool {
        projectMutationGate.contains(projectID)
    }

    func load() async {
        do {
            var shouldRefreshAccess = false
            switch try await store.load() {
            case .loaded(let envelope), .empty(let envelope):
                projects = envelope.projects
                shouldRefreshAccess = !projects.isEmpty
            case .recoveredFromCorruption(let envelope):
                projects = envelope.projects
                await presentRecovery(
                    "Configuration was reset safely. The unreadable file was preserved for diagnosis.",
                    severity: .warning
                )
            case .recoveryRequired(let envelope):
                projects = envelope.projects
                await presentRecovery(
                    "Configuration could not be read and remains unchanged. Restore storage access and relaunch before changing projects.",
                    severity: .error
                )
            case .unsupportedFutureVersion:
                projects = []
                await presentRecovery(
                    "This configuration was created by a newer version and was preserved unchanged.",
                    severity: .error
                )
            }
            if shouldRefreshAccess {
                await refreshRestoredAccess()
            }
            if selectedProjectID == nil || !projects.contains(where: { $0.id == selectedProjectID }) {
                selectedProjectID = projects.first?.id
            }
        } catch {
            await presentRecovery(
                "Projects could not be loaded. Your configuration was preserved; retry or restore it.",
                severity: .error
            )
        }
    }

    func addProject() async {
        guard !isAddingProject else { return }
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
        guard beginMutation(for: project.id) else { return }
        defer { endMutation(for: project.id) }
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
        guard beginMutation(for: project.id) else { return }
        defer { endMutation(for: project.id) }
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
        guard beginMutation(for: project.id) else { return }
        defer { endMutation(for: project.id) }
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
        guard beginMutation(for: project.id) else { return }
        defer { endMutation(for: project.id) }
        do {
            projects = try await store.remove(projectID: project.id).projects
            if selectedProjectID == project.id { selectedProjectID = projects.first?.id }
            await record(.app, .info, "Project configuration removed; source files were not changed.")
        } catch {
            await presentRecovery(
                "The project could not be removed. Its configuration was preserved.",
                severity: .error
            )
        }
    }

    private func refreshRestoredAccess() async {
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
        projectMutationGate.begin(projectID)
    }

    private func endMutation(for projectID: UUID) {
        projectMutationGate.end(projectID)
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
        guard projects.isEmpty else { return }
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
}
