import XCTest
@testable import LiveReloadApp
import LiveReloadCore

final class LiveReloadAppTests: XCTestCase {
    func testAppTargetLoads() {
        XCTAssertEqual(LiveReloadCoreVersion.schemaVersion, 1)
    }

    @MainActor
    func testLoadRefreshesPersistedFolderAccessState() async throws {
        let fixture = try AppModelFixture()
        defer { fixture.remove() }
        let project = try fixture.project(named: "Missing Project")
        _ = try await fixture.store.load()
        _ = try await fixture.store.add(project)
        let provider = FakeFolderAccessProvider(mode: .missing)
        let model = AppModel(store: fixture.store, provider: provider, automaticallyLoad: false)

        await model.load()

        XCTAssertEqual(model.projects.first?.folderAccessState, .missing)
        XCTAssertTrue(model.activities.contains { $0.category == .folderAccess && $0.severity == .warning })
    }

    @MainActor
    func testRemovingSelectedProjectSelectsRemainingProject() async throws {
        let fixture = try AppModelFixture()
        defer { fixture.remove() }
        _ = try await fixture.store.load()
        let first = try fixture.project(named: "First")
        let second = try fixture.project(named: "Second")
        _ = try await fixture.store.add(first)
        _ = try await fixture.store.add(second)
        let model = AppModel(
            store: fixture.store,
            provider: FakeFolderAccessProvider(),
            automaticallyLoad: false
        )
        await model.load()
        model.selectedProjectID = first.id

        await model.remove(first)

        XCTAssertEqual(model.projects.map(\.id), [second.id])
        XCTAssertEqual(model.selectedProjectID, second.id)
    }

    @MainActor
    func testAppModelRejectsDuplicateMutationWithoutBlockingAnotherProject() async throws {
        let fixture = try AppModelFixture()
        defer { fixture.remove() }
        _ = try await fixture.store.load()
        let first = try fixture.project(named: "First")
        let second = try fixture.project(named: "Second")
        _ = try await fixture.store.add(first)
        _ = try await fixture.store.add(second)
        let checkpoint = MutationCheckpoint()
        let model = AppModel(
            store: fixture.store,
            provider: FakeFolderAccessProvider(),
            automaticallyLoad: false,
            beforeProjectMutation: { projectID in await checkpoint.pause(projectID) }
        )
        await model.load()

        let firstMutation = Task { await model.rename(first, to: "First accepted") }
        let firstDidPause = await checkpoint.waitUntilPaused(first.id)
        XCTAssertTrue(firstDidPause)
        XCTAssertTrue(model.isProjectMutationPending(first.id))

        await model.rename(first, to: "Duplicate rejected")
        let secondMutation = Task { await model.rename(second, to: "Second accepted") }
        let secondDidPause = await checkpoint.waitUntilPaused(second.id)
        XCTAssertTrue(secondDidPause)

        XCTAssertTrue(model.isProjectMutationPending(first.id))
        XCTAssertTrue(model.isProjectMutationPending(second.id))
        await checkpoint.resume(first.id)
        await checkpoint.resume(second.id)
        await firstMutation.value
        await secondMutation.value

        XCTAssertEqual(model.projects.first { $0.id == first.id }?.displayName, "First accepted")
        XCTAssertEqual(model.projects.first { $0.id == second.id }?.displayName, "Second accepted")
        XCTAssertFalse(model.isProjectMutationPending(first.id))
        XCTAssertFalse(model.isProjectMutationPending(second.id))
    }

    @MainActor
    func testFutureConfigurationEntersWriteProtectedRecoveryState() async throws {
        let fixture = try AppModelFixture()
        defer { fixture.remove() }
        try Data(#"{"schemaVersion":999,"futureShape":true}"#.utf8)
            .write(to: fixture.storeURL)
        let model = AppModel(
            store: fixture.store,
            provider: FakeFolderAccessProvider(),
            automaticallyLoad: false
        )

        await model.load()

        XCTAssertEqual(model.configurationStoreState, .newerVersion(999))
        XCTAssertFalse(model.canMutateProjects)
    }

    @MainActor
    func testApplicationSupportFailureEntersRecoveryStateWithoutCrashing() {
        let model = AppModel(
            arguments: [],
            environment: [:],
            automaticallyLoad: false,
            storeURLResolver: { throw StoreLocationError.unavailable }
        )

        XCTAssertEqual(model.configurationStoreState, .unavailable)
        XCTAssertFalse(model.canMutateProjects)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.activities.last?.category, .storage)
        XCTAssertEqual(model.activities.last?.severity, .error)
    }
}

private enum StoreLocationError: Error {
    case unavailable
}

private actor MutationCheckpoint {
    private var pausedProjectIDs: Set<UUID> = []
    private var continuations: [UUID: CheckedContinuation<Void, Never>] = [:]

    func pause(_ projectID: UUID) async {
        pausedProjectIDs.insert(projectID)
        await withCheckedContinuation { continuation in
            continuations[projectID] = continuation
        }
    }

    func waitUntilPaused(_ projectID: UUID, timeout: Duration = .seconds(2)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !pausedProjectIDs.contains(projectID) {
            guard ContinuousClock.now < deadline else { return false }
            await Task.yield()
        }
        return true
    }

    func resume(_ projectID: UUID) {
        continuations.removeValue(forKey: projectID)?.resume()
    }
}

private struct AppModelFixture {
    let directory: URL
    let store: ProjectStore
    let storeURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "LiveReloadAppTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appending(path: "projects.json")
        store = ProjectStore(fileURL: storeURL)
    }

    func project(named name: String) throws -> ProjectConfiguration {
        let folder = directory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let reference = try FolderReference(
            bookmarkData: Data("bookmark".utf8),
            normalizedIdentity: FolderReference.normalizedIdentity(for: folder),
            displayLabel: name
        )
        return try ProjectConfiguration(displayName: name, folderReference: reference)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
