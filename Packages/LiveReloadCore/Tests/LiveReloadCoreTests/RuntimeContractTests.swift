import Foundation
import Testing
@testable import LiveReloadCore

@Test func monitoringLifecycleAllowsOnlyDocumentedTransitions() {
    #expect(MonitoringRuntimeState.stopped.canTransition(to: .starting))
    #expect(MonitoringRuntimeState.starting.canTransition(to: .watching))
    #expect(MonitoringRuntimeState.starting.canTransition(to: .failed))
    #expect(MonitoringRuntimeState.watching.canTransition(to: .stopping))
    #expect(MonitoringRuntimeState.watching.canTransition(to: .recovering))
    #expect(MonitoringRuntimeState.recovering.canTransition(to: .stopped))
    #expect(MonitoringRuntimeState.failed.canTransition(to: .stopped))

    #expect(!MonitoringRuntimeState.stopped.canTransition(to: .watching))
    #expect(!MonitoringRuntimeState.recovering.canTransition(to: .watching))
    #expect(!MonitoringRuntimeState.failed.canTransition(to: .starting))
}

@Test func fileChangeSignalsRequireBoundedProjectRelativePaths() throws {
    let projectID = UUID()
    let signal = try FileChangeSignal.change(
        projectID: projectID,
        relativePath: "Sources/Caf\u{00E9}.swift",
        kind: .modified,
        sequence: 42
    )

    #expect(signal.projectID == projectID)
    #expect(signal.relativePath == "Sources/Caf\u{00E9}.swift")
    #expect(signal.kind == .modified)
    #expect(signal.recoveryReason == nil)
    #expect(signal.sequence == 42)

    #expect(throws: RuntimeModelValidationError.pathMustBeRelative) {
        _ = try FileChangeSignal.change(
            projectID: projectID,
            relativePath: "/Users/private/project/index.html",
            kind: .modified,
            sequence: 1
        )
    }
    #expect(throws: RuntimeModelValidationError.pathEscapesProject) {
        _ = try FileChangeSignal.change(
            projectID: projectID,
            relativePath: "../secret.txt",
            kind: .modified,
            sequence: 1
        )
    }
    #expect(throws: RuntimeModelValidationError.pathTooLong) {
        _ = try FileChangeSignal.change(
            projectID: projectID,
            relativePath: String(repeating: "x", count: FileChangeSignal.maximumRelativePathLength + 1),
            kind: .modified,
            sequence: 1
        )
    }

    let recovery = FileChangeSignal.recovery(
        projectID: projectID,
        reason: .eventsDropped,
        sequence: 43
    )
    #expect(recovery.relativePath == nil)
    #expect(recovery.kind == nil)
    #expect(recovery.recoveryReason == .eventsDropped)
}

@Test func changeBatchKeepsFirstSeenOrderAndBoundsItsValues() throws {
    let projectID = UUID()
    let batch = try ChangeBatch(
        projectID: projectID,
        relativePaths: ["styles/main.css", "index.html", "styles/main.css"],
        classification: .fullPage,
        receivedAt: Date(timeIntervalSince1970: 123)
    )

    #expect(batch.relativePaths == ["styles/main.css", "index.html"])
    #expect(batch.classification == .fullPage)
    #expect(batch.receivedAt == Date(timeIntervalSince1970: 123))

    #expect(throws: RuntimeModelValidationError.emptyChangeBatch) {
        _ = try ChangeBatch(projectID: projectID, relativePaths: [], classification: .fullPage)
    }
    #expect(throws: RuntimeModelValidationError.tooManyPaths) {
        _ = try ChangeBatch(
            projectID: projectID,
            relativePaths: (0...ChangeBatch.maximumPathCount).map { "file-\($0).txt" },
            classification: .fullPage
        )
    }
}

@Test func reloadDecisionsConservativelyMapBatchesAndManualRequests() throws {
    let projectID = UUID()
    let stylesheetBatch = try ChangeBatch(
        projectID: projectID,
        relativePaths: ["styles/main.css"],
        classification: .stylesheetOnly
    )
    let mixedBatch = try ChangeBatch(
        projectID: projectID,
        relativePaths: ["styles/main.css", "index.html"],
        classification: .fullPage
    )

    #expect(ReloadDecision(batch: stylesheetBatch).mode == .stylesheet)
    #expect(ReloadDecision(batch: stylesheetBatch).reason == .settledChanges)
    #expect(ReloadDecision(batch: mixedBatch).mode == .fullPage)

    let manual = ReloadDecision.manual(projectID: projectID)
    #expect(manual.reason == .manual)
    #expect(manual.mode == .fullPage)
    #expect(manual.relativePaths.isEmpty)
}

@Test func browserSessionLifecycleRequiresNegotiationBeforeReady() throws {
    #expect(BrowserSessionState.connected.canTransition(to: .negotiating))
    #expect(BrowserSessionState.negotiating.canTransition(to: .ready))
    #expect(BrowserSessionState.negotiating.canTransition(to: .rejected))
    #expect(BrowserSessionState.ready.canTransition(to: .closing))
    #expect(BrowserSessionState.ready.canTransition(to: .failed))
    #expect(BrowserSessionState.closing.canTransition(to: .closed))
    #expect(!BrowserSessionState.connected.canTransition(to: .ready))
    #expect(!BrowserSessionState.closed.canTransition(to: .connected))

    let id = BrowserSessionID()
    let ready = try BrowserSessionSnapshot(
        id: id,
        state: .ready,
        negotiatedProtocolVersion: BrowserSessionSnapshot.supportedProtocolVersion
    )
    #expect(ready.id == id)
    #expect(ready.isReady)

    #expect(throws: RuntimeModelValidationError.missingProtocolNegotiation) {
        _ = try BrowserSessionSnapshot(id: id, state: .ready)
    }
    #expect(throws: RuntimeModelValidationError.unsupportedProtocolVersion(6)) {
        _ = try BrowserSessionSnapshot(id: id, state: .ready, negotiatedProtocolVersion: 6)
    }
}

@Test func serverStateRejectsInvalidConnectionCounts() throws {
    let listening = try ServerState.listening(clientCount: 2)
    #expect(listening.phase == .listening)
    #expect(listening.clientCount == 2)

    #expect(throws: RuntimeModelValidationError.invalidClientCount) {
        _ = try ServerState.listening(clientCount: -1)
    }
    #expect(throws: RuntimeModelValidationError.invalidClientCount) {
        _ = try ServerState.listening(clientCount: ServerState.maximumClientCount + 1)
    }
}
