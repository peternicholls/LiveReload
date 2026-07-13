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
}

private struct AppModelFixture {
    let directory: URL
    let store: ProjectStore

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "LiveReloadAppTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = ProjectStore(fileURL: directory.appending(path: "projects.json"))
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
