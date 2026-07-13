import Foundation
import LiveReloadCore
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var isLoading = true
    private(set) var projects: [ProjectConfiguration] = []
    private(set) var activities: [ActivityEvent] = []
    var selectedProjectID: UUID?
    var recoveryMessage: String?

    private let store: ProjectStore
    private let activityStore = ActivityStore()
    private let provider: any FolderAccessProvider

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let isUITesting = arguments.contains { $0.hasPrefix("--ui-testing-") }
        let url: URL
        if isUITesting, let testStorePath = environment["LIVERELOAD_UI_TEST_STORE"] {
            url = URL(fileURLWithPath: testStorePath)
            provider = FakeFolderAccessProvider()
        } else {
            url = try! ProjectStore.applicationSupportURL()
            provider = SecurityScopedBookmarkProvider()
        }
        store = ProjectStore(fileURL: url)
        Task {
            if arguments.contains("--ui-testing-delay-load") {
                try? await Task.sleep(for: .seconds(3))
            }
            if arguments.contains("--ui-testing-corrupt") {
                try? Data("not-json".utf8).write(to: url)
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

    func load() async {
        do {
            switch try await store.load() {
            case .loaded(let envelope), .empty(let envelope):
                projects = envelope.projects
            case .recoveredFromCorruption(let envelope):
                projects = envelope.projects
                recoveryMessage = "Configuration was reset safely. The unreadable file was preserved for diagnosis."
                await record(.storage, .warning, recoveryMessage!)
            case .unsupportedFutureVersion:
                recoveryMessage = "This configuration was created by a newer version and was preserved unchanged."
                await record(.storage, .error, recoveryMessage!)
            }
            if selectedProjectID == nil || !projects.contains(where: { $0.id == selectedProjectID }) {
                selectedProjectID = projects.first?.id
            }
        } catch {
            recoveryMessage = "Projects could not be loaded. Your configuration was preserved; retry or restore it."
            await record(.storage, .error, recoveryMessage!)
        }
    }

    func addProject() async {
        guard let url = FolderPicker.chooseFolder() else { return }
        do {
            let reference = try await provider.createReference(for: url)
            let project = try ProjectConfiguration(displayName: url.lastPathComponent, folderReference: reference)
            projects = try await store.add(project).projects
            selectedProjectID = project.id
            await record(.folderAccess, .info, "Project access added.", projectID: project.id)
        } catch ProjectStoreError.duplicateFolderIdentity {
            recoveryMessage = "That folder is already configured. The existing project was preserved."
        } catch {
            recoveryMessage = "The project could not be added. No existing configuration was changed."
        }
    }

    func rename(_ project: ProjectConfiguration, to name: String) async {
        do {
            var updated = project
            try updated.rename(to: name)
            projects = try await store.update(updated).projects
        } catch {
            recoveryMessage = "The name was not changed. Enter a name between 1 and 120 characters."
        }
    }

    func setEnabled(_ project: ProjectConfiguration, enabled: Bool) async {
        var updated = project
        updated.isEnabled = enabled
        do { projects = try await store.update(updated).projects }
        catch { recoveryMessage = "The setting could not be saved. The previous value was preserved." }
    }

    func repair(_ project: ProjectConfiguration) async {
        guard let url = FolderPicker.chooseFolder(prompt: "Repair Project Access") else { return }
        do {
            let reference = try await provider.repair(project.folderReference, with: url)
            projects = try await store.replaceFolderAccess(projectID: project.id, reference: reference).projects
            await record(.folderAccess, .info, "Project access repaired.", projectID: project.id)
        } catch {
            recoveryMessage = "Access was not repaired. The project and its settings were preserved."
        }
    }

    func remove(_ project: ProjectConfiguration) async {
        do {
            projects = try await store.remove(projectID: project.id).projects
            if selectedProjectID == project.id { selectedProjectID = nil }
            await record(.app, .info, "Project configuration removed; source files were not changed.")
        } catch {
            recoveryMessage = "The project could not be removed. Its configuration was preserved."
        }
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
