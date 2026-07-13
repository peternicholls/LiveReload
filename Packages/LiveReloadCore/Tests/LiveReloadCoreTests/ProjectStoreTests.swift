import Foundation
import Testing
@testable import LiveReloadCore

private func temporaryStore() throws -> (directory: URL, file: URL, store: ProjectStore) {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appending(path: ProjectStore.configurationFilename)
    return (directory, file, ProjectStore(fileURL: file))
}

private func project(for folder: URL, id: UUID = UUID()) throws -> ProjectConfiguration {
    let reference = try FolderReference(
        bookmarkData: Data("fixture".utf8),
        normalizedIdentity: FolderReference.normalizedIdentity(for: folder),
        displayLabel: folder.lastPathComponent
    )
    return try ProjectConfiguration(id: id, displayName: folder.lastPathComponent, folderReference: reference)
}

@Test func missingStoreLoadsEmptyAndRoundTripsAtomically() async throws {
    let fixture = try temporaryStore()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let initial = try await fixture.store.load()
    guard case .empty(let empty) = initial else {
        Issue.record("Expected an empty load")
        return
    }
    #expect(empty.projects.isEmpty)

    let folder = fixture.directory.appending(path: "source", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let expected = try project(for: folder)
    _ = try await fixture.store.add(expected)

    let reloaded = ProjectStore(fileURL: fixture.file)
    let outcome = try await reloaded.load()
    guard case .loaded(let envelope) = outcome else {
        Issue.record("Expected a loaded envelope")
        return
    }
    #expect(envelope.projects == [expected])
}

@Test func corruptStoreIsPreservedAndRecovered() async throws {
    let fixture = try temporaryStore()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    try Data("not-json".utf8).write(to: fixture.file)

    let outcome = try await fixture.store.load()

    guard case .recoveredFromCorruption(let empty) = outcome else {
        Issue.record("Expected corruption recovery")
        return
    }
    #expect(empty.projects.isEmpty)
    let contents = try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path)
    #expect(contents.contains { $0.contains("corrupt-") })
}

@Test func futureStoreIsPreservedAndNeverOverwritten() async throws {
    let fixture = try temporaryStore()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let data = Data(#"{"schemaVersion":99,"projects":[],"createdAt":"2026-07-13T00:00:00Z","updatedAt":"2026-07-13T00:00:00Z"}"#.utf8)
    try data.write(to: fixture.file)

    let outcome = try await fixture.store.load()

    #expect(outcome == .unsupportedFutureVersion(99))
    #expect(try Data(contentsOf: fixture.file) == data)
}

@Test func duplicateIdentityIsRejectedAndRemovalPreservesFolder() async throws {
    let fixture = try temporaryStore()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let folder = fixture.directory.appending(path: "source", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    _ = try await fixture.store.load()
    let first = try project(for: folder)
    _ = try await fixture.store.add(first)

    await #expect(throws: ProjectStoreError.duplicateFolderIdentity) {
        _ = try await fixture.store.add(project(for: folder))
    }
    _ = try await fixture.store.remove(projectID: first.id)
    #expect(FileManager.default.fileExists(atPath: folder.path))
}

@Test func repairRetainsProjectIdentityAndSettings() async throws {
    let fixture = try temporaryStore()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    _ = try await fixture.store.load()
    let originalFolder = fixture.directory.appending(path: "original")
    let replacementFolder = fixture.directory.appending(path: "replacement")
    let id = UUID()
    var original = try project(for: originalFolder, id: id)
    try original.rename(to: "Custom Name")
    original.isEnabled = false
    _ = try await fixture.store.add(original)
    let replacementReference = try FolderReference(
        bookmarkData: Data("replacement".utf8),
        normalizedIdentity: FolderReference.normalizedIdentity(for: replacementFolder),
        displayLabel: replacementFolder.lastPathComponent
    )

    let updated = try await fixture.store.replaceFolderAccess(projectID: id, reference: replacementReference)

    #expect(updated.projects[0].id == id)
    #expect(updated.projects[0].displayName == "Custom Name")
    #expect(updated.projects[0].isEnabled == false)
    #expect(updated.projects[0].folderReference == replacementReference)
}
