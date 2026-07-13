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

    @MainActor
    func testReloadLoopAppModelProjectsLifecycleServerAndManualReloadScenarios() async throws {
        let fixture = try AppModelFixture()
        defer { fixture.remove() }
        _ = try await fixture.store.load()
        let project = try fixture.project(named: "Runtime Contract")
        _ = try await fixture.store.add(project)
        let runtime = ScenarioRuntimeService()
        let model = AppModel(
            store: fixture.store,
            provider: FakeFolderAccessProvider(),
            automaticallyLoad: false,
            runtimeService: runtime
        )
        await model.load()

        await runtime.setStartProjection(.init(
            monitoringState: .starting,
            recoveryReason: nil,
            lastSafeBatch: nil
        ))
        await model.startMonitoring(project)
        XCTAssertEqual(model.runtimeProjection(for: project.id).monitoringState, .starting)

        await runtime.emitProject(
            project.id,
            .init(monitoringState: .watching, recoveryReason: nil, lastSafeBatch: nil)
        )
        let didStartWatching = await waitUntil {
            model.runtimeProjection(for: project.id).monitoringState == .watching
        }
        XCTAssertTrue(didStartWatching)

        let batch = try ChangeBatch(
            projectID: project.id,
            relativePaths: ["Styles/site.css"],
            classification: .stylesheetOnly
        )
        await runtime.emitProject(
            project.id,
            .init(monitoringState: .watching, recoveryReason: nil, lastSafeBatch: batch)
        )
        let didPublishBatch = await waitUntil {
            model.runtimeProjection(for: project.id).lastSafeBatch == batch
        }
        XCTAssertTrue(didPublishBatch)

        await runtime.emitProject(
            project.id,
            .init(monitoringState: .recovering, recoveryReason: .eventsDropped, lastSafeBatch: batch)
        )
        let didEnterRecovery = await waitUntil {
            model.runtimeProjection(for: project.id).monitoringState == .recovering
        }
        XCTAssertTrue(didEnterRecovery)
        await model.stopMonitoring(project)
        XCTAssertEqual(model.runtimeProjection(for: project.id).monitoringState, .stopped)

        await runtime.setRetryProjection(.init(
            monitoringState: .failed,
            recoveryReason: .sourceFailure,
            lastSafeBatch: batch
        ))
        await model.retryMonitoring(project)
        XCTAssertEqual(model.runtimeProjection(for: project.id).monitoringState, .failed)
        XCTAssertEqual(model.runtimeProjection(for: project.id).recoveryReason, .sourceFailure)
        XCTAssertEqual(model.recoveryMessage, "Monitoring could not start safely. The project configuration was preserved; retry when ready.")

        await runtime.setServerStartState(.starting)
        await model.startLocalServer()
        XCTAssertEqual(model.serverState, .starting)
        await runtime.emitServer(try .listening(clientCount: 0))
        let noClientsState = try ServerState.listening(clientCount: 0)
        let didPublishNoClients = await waitUntil { model.serverState == noClientsState }
        XCTAssertTrue(didPublishNoClients)
        await runtime.emitServer(.portConflict)
        let didPublishConflict = await waitUntil { model.serverState == .portConflict }
        XCTAssertTrue(didPublishConflict)
        await runtime.emitServer(try .listening(clientCount: 2))
        let didPublishClients = await waitUntil { model.connectedClientCount == 2 }
        XCTAssertTrue(didPublishClients)

        await runtime.emitProject(
            project.id,
            .init(monitoringState: .watching, recoveryReason: nil, lastSafeBatch: batch)
        )
        let didEnableManualReload = await waitUntil { model.canManuallyReload(project.id) }
        XCTAssertTrue(didEnableManualReload)
        await model.manualReload(project)
        let manualReloadCalls = await runtime.manualReloadCallCount()
        XCTAssertEqual(manualReloadCalls, 1)
        XCTAssertEqual(model.activities.last?.category, .pipeline)
        XCTAssertEqual(model.selectedProject?.id, project.id)
        let persistedProject = try await fixture.store.snapshot().projects.first
        XCTAssertEqual(persistedProject, project)
    }

    @MainActor
    func testRuntimeOperationGateRejectsRapidDuplicateAndOverlappingMutation() async throws {
        let fixture = try AppModelFixture()
        defer { fixture.remove() }
        _ = try await fixture.store.load()
        let project = try fixture.project(named: "Operation Gate")
        _ = try await fixture.store.add(project)
        let runtime = ScenarioRuntimeService(pausesStart: true)
        let model = AppModel(
            store: fixture.store,
            provider: FakeFolderAccessProvider(),
            automaticallyLoad: false,
            runtimeService: runtime
        )
        await model.load()

        let firstStart = Task { await model.startMonitoring(project) }
        let startDidPause = await runtime.waitUntilStartPaused()
        XCTAssertTrue(startDidPause)
        XCTAssertTrue(model.isRuntimeOperationPending(project.id))

        await model.startMonitoring(project)
        await model.rename(project, to: "Overlapping rename")
        let startCalls = await runtime.startCallCount()
        XCTAssertEqual(startCalls, 1)
        XCTAssertEqual(model.projects.first?.displayName, project.displayName)

        await runtime.resumeStart()
        await firstStart.value
        XCTAssertFalse(model.isRuntimeOperationPending(project.id))
        XCTAssertEqual(model.runtimeProjection(for: project.id).monitoringState, .watching)
    }

    @MainActor
    func testLiveRuntimeCompositionUsesResolvedRootReleasesScopeAndPublishesRecovery() async throws {
        let fixture = try AppModelFixture()
        defer { fixture.remove() }
        _ = try await fixture.store.load()
        let folder = fixture.directory.appending(path: "Observed Root", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let provider = FakeFolderAccessProvider()
        let reference = try await provider.createReference(for: folder)
        let project = try ProjectConfiguration(displayName: "Observed Root", folderReference: reference)
        _ = try await fixture.store.add(project)
        let source = FakeFileEventSource()
        let server = FakeReloadServer()
        let browser = FakeBrowserSession()
        try await browser.transition(to: .negotiating)
        try await browser.transition(to: .ready, negotiatedProtocolVersion: 7)
        await server.addSession(browser)
        let runtime = LiveReloadLoopRuntimeService(
            provider: provider,
            eventSource: source,
            server: server
        )
        let model = AppModel(
            store: fixture.store,
            provider: provider,
            automaticallyLoad: false,
            runtimeService: runtime
        )
        await model.load()
        let didReleaseLoadProbe = await waitUntil {
            let counts = await provider.counts()
            return counts.began == counts.ended
        }
        XCTAssertTrue(didReleaseLoadProbe)
        let baselineAccessCounts = await provider.counts()

        await model.startLocalServer()
        XCTAssertEqual(model.serverState, try .listening(clientCount: 1))
        await model.startMonitoring(project)
        XCTAssertEqual(model.runtimeProjection(for: project.id).monitoringState, .watching)
        let latestStream = await source.latestStream()
        let stream = try XCTUnwrap(latestStream)
        let observedRoot = await stream.rootURL.standardizedFileURL
        XCTAssertEqual(observedRoot, folder.standardizedFileURL)
        let initialAccessCounts = await provider.counts()
        XCTAssertEqual(initialAccessCounts.began, baselineAccessCounts.began + 1)

        await stream.emit(.recovery(projectID: project.id, reason: .rootChanged, sequence: 1))
        let didPublishRecovery = await waitUntil {
            model.runtimeProjection(for: project.id).monitoringState == .recovering
        }
        XCTAssertTrue(didPublishRecovery)
        XCTAssertEqual(model.runtimeProjection(for: project.id).recoveryReason, .rootChanged)
        let didReleaseFirstScope = await waitUntil {
            await provider.counts().ended == baselineAccessCounts.ended + 1
        }
        XCTAssertTrue(didReleaseFirstScope)

        await model.retryMonitoring(project)
        XCTAssertEqual(model.runtimeProjection(for: project.id).monitoringState, .watching)
        let retryAccessCounts = await provider.counts()
        XCTAssertEqual(retryAccessCounts.began, baselineAccessCounts.began + 2)
        let latestRetryStream = await source.latestStream()
        let retryStream = try XCTUnwrap(latestRetryStream)
        let changedPath = "Styles/retry.css"
        await retryStream.emit(try .change(
            projectID: project.id,
            relativePath: changedPath,
            kind: .modified,
            sequence: 2
        ))
        let didPublishSettledBatch = await waitUntil {
            model.runtimeProjection(for: project.id).lastSafeBatch?.relativePaths == [changedPath]
        }
        XCTAssertTrue(didPublishSettledBatch)
        let didEnableManualReload = await waitUntil { model.canManuallyReload(project.id) }
        XCTAssertTrue(didEnableManualReload)
        await model.manualReload(project)
        let receivedDecisions = await browser.receivedDecisions()
        XCTAssertEqual(receivedDecisions.count, 2)
        XCTAssertEqual(receivedDecisions.first?.reason, .settledChanges)
        XCTAssertEqual(receivedDecisions.first?.relativePaths, [changedPath])
        XCTAssertEqual(receivedDecisions.last, .manual(projectID: project.id))
        await model.stopMonitoring(project)
        let didReleaseSecondScope = await waitUntil {
            await provider.counts().ended == baselineAccessCounts.ended + 2
        }
        XCTAssertTrue(didReleaseSecondScope)
    }

    @MainActor
    func testRuntimeMapsUnresolvableFolderReferenceToActionableFolderFailure() async throws {
        let fixture = try AppModelFixture()
        defer { fixture.remove() }
        _ = try await fixture.store.load()
        let reference = try FolderReference(
            bookmarkData: Data([0xff]),
            normalizedIdentity: "/invalid-fixture",
            displayLabel: "Unavailable Fixture"
        )
        let project = try ProjectConfiguration(displayName: "Unavailable Fixture", folderReference: reference)
        _ = try await fixture.store.add(project)
        let provider = FakeFolderAccessProvider()
        let runtime = LiveReloadLoopRuntimeService(
            provider: provider,
            eventSource: FakeFileEventSource(),
            server: FakeReloadServer()
        )
        let model = AppModel(
            store: fixture.store,
            provider: provider,
            automaticallyLoad: false,
            runtimeService: runtime
        )
        await model.load()

        await model.startMonitoring(project)

        let projection = model.runtimeProjection(for: project.id)
        XCTAssertEqual(projection.monitoringState, .failed)
        XCTAssertEqual(projection.recoveryReason, .folderUnavailable)
        XCTAssertEqual(
            model.recoveryMessage,
            "Monitoring could not start because folder access is unavailable. Repair access and retry."
        )
    }
}

private actor ScenarioRuntimeService: ReloadLoopRuntimeServing {
    private let pausesStart: Bool
    private let startCheckpoint = RuntimeStartCheckpoint()
    private var startProjection = ProjectRuntimeProjection(
        monitoringState: .watching,
        recoveryReason: nil,
        lastSafeBatch: nil
    )
    private var retryProjection = ProjectRuntimeProjection(
        monitoringState: .watching,
        recoveryReason: nil,
        lastSafeBatch: nil
    )
    private var serverStartState = ServerState.stopped
    private var projects: [UUID: ProjectRuntimeProjection] = [:]
    private var serverState = ServerState.stopped
    private var continuations: [UUID: AsyncStream<ReloadLoopRuntimeUpdate>.Continuation] = [:]
    private var startCalls = 0
    private var manualReloadCalls = 0

    init(pausesStart: Bool = false) {
        self.pausesStart = pausesStart
    }

    func updates() -> AsyncStream<ReloadLoopRuntimeUpdate> {
        let id = UUID()
        let pair = AsyncStream<ReloadLoopRuntimeUpdate>.makeStream(bufferingPolicy: .bufferingNewest(32))
        continuations[id] = pair.continuation
        pair.continuation.yield(.server(serverState))
        for (projectID, projection) in projects {
            pair.continuation.yield(.project(projectID, projection))
        }
        return pair.stream
    }

    func startServer() -> ServerState {
        serverState = serverStartState
        publish(.server(serverState))
        return serverState
    }

    func stopServer() -> ServerState {
        serverState = .stopped
        publish(.server(serverState))
        return serverState
    }

    func startMonitoring(_ project: ProjectConfiguration) async -> ProjectRuntimeProjection {
        startCalls += 1
        if pausesStart { await startCheckpoint.pause() }
        projects[project.id] = startProjection
        publish(.project(project.id, startProjection))
        return startProjection
    }

    func stopMonitoring(projectID: UUID) -> ProjectRuntimeProjection {
        projects[projectID] = .stopped
        publish(.project(projectID, .stopped))
        return .stopped
    }

    func retryMonitoring(_ project: ProjectConfiguration) -> ProjectRuntimeProjection {
        projects[project.id] = retryProjection
        publish(.project(project.id, retryProjection))
        return retryProjection
    }

    func manualReload(projectID: UUID) -> ReloadBroadcastResult? {
        guard projects[projectID]?.monitoringState == .watching else { return nil }
        manualReloadCalls += 1
        return ReloadBroadcastResult(readyClientCount: serverState.clientCount, sentCount: serverState.clientCount, failedCount: 0)
    }

    func setStartProjection(_ projection: ProjectRuntimeProjection) { startProjection = projection }
    func setRetryProjection(_ projection: ProjectRuntimeProjection) { retryProjection = projection }
    func setServerStartState(_ state: ServerState) { serverStartState = state }
    func startCallCount() -> Int { startCalls }
    func manualReloadCallCount() -> Int { manualReloadCalls }
    func waitUntilStartPaused() async -> Bool { await startCheckpoint.waitUntilPaused() }
    func resumeStart() async { await startCheckpoint.resume() }

    func emitProject(_ projectID: UUID, _ projection: ProjectRuntimeProjection) {
        projects[projectID] = projection
        publish(.project(projectID, projection))
    }

    func emitServer(_ state: ServerState) {
        serverState = state
        publish(.server(state))
    }

    private func publish(_ update: ReloadLoopRuntimeUpdate) {
        for continuation in continuations.values { continuation.yield(update) }
    }
}

private actor RuntimeStartCheckpoint {
    private var isPaused = false
    private var continuation: CheckedContinuation<Void, Never>?

    func pause() async {
        isPaused = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilPaused(timeout: Duration = .seconds(2)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !isPaused {
            guard ContinuousClock.now < deadline else { return false }
            await Task.yield()
        }
        return true
    }

    func resume() {
        continuation?.resume()
        continuation = nil
        isPaused = false
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    _ predicate: @MainActor () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !(await predicate()) {
        guard ContinuousClock.now < deadline else { return false }
        await Task.yield()
    }
    return true
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
