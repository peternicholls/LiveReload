import Foundation
import Testing
@testable import LiveReloadCore

@Test func fakeProviderCoversAccessOutcomesAndBalancesScope() async throws {
    let provider = FakeFolderAccessProvider()
    let url = FileManager.default.temporaryDirectory.appending(path: "fixture")
    let reference = try await provider.createReference(for: url)
    #expect(await provider.resolve(reference) == .available(reference: reference))

    let token = try await provider.beginAccess(to: reference)
    token.release()
    for _ in 0..<10 {
        if await provider.counts().ended == 1 { break }
        await Task.yield()
    }
    let counts = await provider.counts()
    #expect(counts.began == 1)
    #expect(counts.ended == 1)

    await provider.setMode(.stale)
    #expect(await provider.resolve(reference) == .stale(reference: reference))
    await provider.setMode(.missing)
    #expect(await provider.resolve(reference) == .missing)
    await provider.setMode(.denied)
    #expect(await provider.resolve(reference) == .denied)
    await provider.setMode(.corrupt)
    #expect(await provider.resolve(reference) == .corrupt)
}

@Test func fakeProviderRepairSupportsSuccessAndCancellation() async throws {
    let provider = FakeFolderAccessProvider(mode: .stale)
    let originalURL = FileManager.default.temporaryDirectory.appending(path: "original")
    let replacementURL = FileManager.default.temporaryDirectory.appending(path: "replacement")
    let original = try await provider.createReference(for: originalURL)

    await #expect(throws: FolderAccessError.repairCancelled) {
        _ = try await provider.repair(original, with: nil)
    }
    let repaired = try await provider.repair(original, with: replacementURL)
    #expect(repaired.normalizedIdentity == FolderReference.normalizedIdentity(for: replacementURL))
    #expect(await provider.resolve(repaired) == .available(reference: repaired))
}

@Test func coordinatorPersistsFailureStateWithoutDiscardingProject() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = ProjectStore(fileURL: directory.appending(path: "projects.json"))
    _ = try await store.load()
    let provider = FakeFolderAccessProvider(mode: .missing)
    let folder = directory.appending(path: "missing")
    let reference = try await provider.createReference(for: folder)
    let project = try ProjectConfiguration(displayName: "Retained", folderReference: reference)
    _ = try await store.add(project)
    let coordinator = ProjectAccessCoordinator(store: store, provider: provider)

    let state = try await coordinator.refreshAccess(for: project.id)
    let snapshot = try await store.snapshot()

    #expect(state == .missing)
    #expect(snapshot.projects.count == 1)
    #expect(snapshot.projects[0].id == project.id)
    #expect(snapshot.projects[0].folderAccessState == .missing)
}

@Test func coordinatorProvesAndBalancesScopedAccessBeforeMarkingAvailable() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = ProjectStore(fileURL: directory.appending(path: "projects.json"))
    _ = try await store.load()
    let provider = FakeFolderAccessProvider(mode: .available)
    let reference = try await provider.createReference(for: directory.appending(path: "source"))
    let project = try ProjectConfiguration(
        displayName: "Restored",
        folderReference: reference,
        folderAccessState: .needsRepair
    )
    _ = try await store.add(project)
    let coordinator = ProjectAccessCoordinator(store: store, provider: provider)

    #expect(try await coordinator.refreshAccess(for: project.id) == .available)
    for _ in 0..<10 where await provider.counts().ended == 0 {
        await Task.yield()
    }

    let counts = await provider.counts()
    #expect(counts.began == 1)
    #expect(counts.ended == 1)
    let firstSnapshot = try await store.snapshot()
    #expect(firstSnapshot.projects[0].folderAccessState == .available)

    #expect(try await coordinator.refreshAccess(for: project.id) == .available)
    let secondSnapshot = try await store.snapshot()
    #expect(secondSnapshot.updatedAt == firstSnapshot.updatedAt)
}

@Test func coordinatorMapsFailedScopedAccessToDenied() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = ProjectStore(fileURL: directory.appending(path: "projects.json"))
    _ = try await store.load()
    let provider = ResolvesAvailableButDeniesAccessProvider()
    let reference = try FolderReference(
        bookmarkData: Data("bookmark".utf8),
        normalizedIdentity: "/source",
        displayLabel: "source"
    )
    let project = try ProjectConfiguration(displayName: "Denied", folderReference: reference)
    _ = try await store.add(project)
    let coordinator = ProjectAccessCoordinator(store: store, provider: provider)

    #expect(try await coordinator.refreshAccess(for: project.id) == .denied)
    #expect(try await store.snapshot().projects[0].folderAccessState == .denied)
}

private struct ResolvesAvailableButDeniesAccessProvider: FolderAccessProvider {
    func createReference(for selectedURL: URL) async throws -> FolderReference {
        throw FolderAccessError.selectionRequired
    }

    func resolve(_ reference: FolderReference) async -> FolderAccessOutcome {
        .available(reference: reference)
    }

    func resolvedURL(for reference: FolderReference) async throws -> URL {
        throw FolderAccessError.accessDenied
    }

    func beginAccess(to reference: FolderReference) async throws -> ScopedAccessToken {
        throw FolderAccessError.accessDenied
    }

    func repair(_ reference: FolderReference, with selectedURL: URL?) async throws -> FolderReference {
        throw FolderAccessError.repairCancelled
    }
}
