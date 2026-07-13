import Foundation
import Testing
@testable import LiveReloadCore

@Suite("Project reload pipeline")
struct ProjectPipelineTests {
    @Test("settled stylesheet and mixed batches broadcast one conservative decision")
    func settledDecisions() async throws {
        let fixture = try await PipelineFixture(clientCount: 1)
        await fixture.pipeline.setMonitoringState(.watching)

        await fixture.pipeline.receive(try .change(
            projectID: fixture.projectID,
            relativePath: "styles/site.css",
            kind: .modified,
            sequence: 1
        ))
        await fixture.waitForSettlement()
        #expect(await fixture.session(0).receivedDecisions().map(\.mode) == [.stylesheet])

        await fixture.pipeline.receive(try .change(
            projectID: fixture.projectID,
            relativePath: "index.html",
            kind: .modified,
            sequence: 2
        ))
        await fixture.waitForSettlement()
        #expect(await fixture.session(0).receivedDecisions().map(\.mode) == [.stylesheet, .fullPage])
    }

    @Test("manual reload requires watching and always requests a full page")
    func manualReload() async throws {
        let fixture = try await PipelineFixture(clientCount: 1)
        #expect(await fixture.pipeline.manualReload() == nil)
        await fixture.pipeline.setMonitoringState(.watching)

        let result = await fixture.pipeline.manualReload()

        #expect(result?.sentCount == 1)
        #expect(await fixture.session(0).receivedDecisions().last?.reason == .manual)
        #expect(await fixture.session(0).receivedDecisions().last?.mode == .fullPage)
    }

    @Test("excluded, stopped, recovering, and no-client paths suppress delivery")
    func suppression() async throws {
        let fixture = try await PipelineFixture(clientCount: 0, userPatterns: ["generated/"])
        await fixture.pipeline.setMonitoringState(.watching)
        await fixture.pipeline.receive(try .change(
            projectID: fixture.projectID,
            relativePath: "generated/app.js",
            kind: .modified,
            sequence: 1
        ))
        #expect(await fixture.clock.pendingSleepCount() == 0)

        await fixture.pipeline.receive(try .change(
            projectID: fixture.projectID,
            relativePath: "index.html",
            kind: .modified,
            sequence: 2
        ))
        await fixture.pipeline.setMonitoringState(.recovering, reason: .eventsDropped)
        await fixture.clock.advance(by: .seconds(1))
        #expect(await fixture.pipeline.lastBroadcastResult() == nil)

        await fixture.pipeline.setMonitoringState(.stopped)
        await fixture.pipeline.receive(try .change(
            projectID: fixture.projectID,
            relativePath: "late.html",
            kind: .modified,
            sequence: 3
        ))
        #expect(await fixture.clock.pendingSleepCount() == 0)
    }

    @Test("one settled decision reaches every ready client")
    func multipleClients() async throws {
        let fixture = try await PipelineFixture(clientCount: 2)
        await fixture.pipeline.setMonitoringState(.watching)
        await fixture.pipeline.receive(try .change(
            projectID: fixture.projectID,
            relativePath: "index.html",
            kind: .modified,
            sequence: 1
        ))
        await fixture.waitForSettlement()

        #expect(await fixture.session(0).receivedDecisions().count == 1)
        #expect(await fixture.session(1).receivedDecisions().count == 1)
        #expect(await fixture.pipeline.lastBroadcastResult()?.sentCount == 2)
    }

    @Test("a settled batch with no clients records zero delivery without suppressing settlement")
    func noClients() async throws {
        let fixture = try await PipelineFixture(clientCount: 0)
        await fixture.pipeline.setMonitoringState(.watching)
        await fixture.pipeline.receive(try .change(
            projectID: fixture.projectID,
            relativePath: "index.html",
            kind: .modified,
            sequence: 1
        ))
        await fixture.waitForSettlement()

        #expect(await fixture.pipeline.lastSettledBatch()?.relativePaths == ["index.html"])
        #expect(await fixture.pipeline.lastBroadcastResult() == ReloadBroadcastResult(
            readyClientCount: 0,
            sentCount: 0,
            failedCount: 0
        ))
    }

    @Test("recovery cancels a settled broadcast before late delivery")
    func recoveryCancelsInFlightBroadcast() async throws {
        let projectID = UUID()
        let clock = DeterministicReloadClock()
        let server = BlockingReloadServer()
        let pipeline = try ProjectPipeline(
            projectID: projectID,
            server: server,
            policy: ExclusionPolicy(),
            clock: clock
        )
        await pipeline.setMonitoringState(.watching)
        await pipeline.receive(try .change(
            projectID: projectID,
            relativePath: "index.html",
            kind: .modified,
            sequence: 1
        ))
        await eventually {
            let scheduled = await pipeline.isSettlementScheduled()
            let sleepers = await clock.pendingSleepCount()
            return scheduled && sleepers == 1
        }
        await clock.advance(by: .milliseconds(250))
        await eventually { await server.hasPendingBroadcast() }

        await pipeline.setMonitoringState(.recovering, reason: .eventsDropped)
        await server.releaseBroadcast()
        await eventually { !(await server.hasPendingBroadcast()) }

        #expect(await server.deliveredDecisions().isEmpty)
        #expect(await pipeline.lastBroadcastResult() == nil)
        #expect(await pipeline.state() == .recovering)
    }

    @Test("settled batches publish one bounded presentation update")
    func settledBatchUpdate() async throws {
        let updates = PipelineUpdateRecorder()
        let projectID = UUID()
        let clock = DeterministicReloadClock()
        let server = FakeReloadServer()
        await server.start()
        let pipeline = try ProjectPipeline(
            projectID: projectID,
            server: server,
            policy: ExclusionPolicy(),
            clock: clock,
            onSettled: { batch, result in await updates.append(batch: batch, result: result) }
        )
        await pipeline.setMonitoringState(.watching)
        await pipeline.receive(try .change(
            projectID: projectID,
            relativePath: "styles/site.css",
            kind: .modified,
            sequence: 1
        ))
        await eventually {
            let scheduled = await pipeline.isSettlementScheduled()
            let sleeperCount = await clock.pendingSleepCount()
            return scheduled && sleeperCount == 1
        }
        await clock.advance(by: .milliseconds(250))
        await eventually { await updates.values().count == 1 }

        let update = try #require(await updates.values().first)
        #expect(update.batch.relativePaths == ["styles/site.css"])
        #expect(update.result == ReloadBroadcastResult(readyClientCount: 0, sentCount: 0, failedCount: 0))
    }
}

private struct PipelineFixture: Sendable {
    let projectID: UUID
    let clock: DeterministicReloadClock
    let server: FakeReloadServer
    let sessions: [FakeBrowserSession]
    let pipeline: ProjectPipeline

    init(clientCount: Int, userPatterns: [String] = []) async throws {
        projectID = UUID()
        clock = DeterministicReloadClock()
        server = FakeReloadServer()
        var sessions: [FakeBrowserSession] = []
        for _ in 0..<clientCount {
            let session = FakeBrowserSession()
            try await session.transition(to: .negotiating)
            try await session.transition(to: .ready, negotiatedProtocolVersion: 7)
            await server.addSession(session)
            sessions.append(session)
        }
        self.sessions = sessions
        await server.start()
        pipeline = try ProjectPipeline(
            projectID: projectID,
            server: server,
            policy: ExclusionPolicy(userPatterns: userPatterns),
            clock: clock
        )
    }

    func session(_ index: Int) -> FakeBrowserSession { sessions[index] }

    func waitForSettlement() async {
        let previousBroadcastCount = await pipeline.broadcastCount()
        await eventually {
            let scheduled = await pipeline.isSettlementScheduled()
            let sleepers = await clock.pendingSleepCount()
            return scheduled && sleepers == 1
        }
        await clock.advance(by: .milliseconds(250))
        await eventually { await pipeline.broadcastCount() == previousBroadcastCount + 1 }
    }
}

private actor PipelineUpdateRecorder {
    struct Update: Sendable {
        let batch: ChangeBatch
        let result: ReloadBroadcastResult
    }

    private var updates: [Update] = []

    func append(batch: ChangeBatch, result: ReloadBroadcastResult) {
        updates.append(Update(batch: batch, result: result))
    }

    func values() -> [Update] { updates }
}

private actor BlockingReloadServer: ReloadServerControlling {
    private var continuation: CheckedContinuation<Void, Never>?
    private var decisions: [ReloadDecision] = []

    func start() async {}
    func stop() async { continuation?.resume(); continuation = nil }
    func currentState() async -> ServerState { try! .listening(clientCount: 1) }
    func stateUpdates() async -> AsyncStream<ServerState> {
        AsyncStream { $0.yield(try! .listening(clientCount: 1)); $0.finish() }
    }

    func broadcast(_ decision: ReloadDecision) async -> ReloadBroadcastResult {
        await withCheckedContinuation { continuation = $0 }
        guard !Task.isCancelled else {
            return ReloadBroadcastResult(readyClientCount: 1, sentCount: 0, failedCount: 0)
        }
        decisions.append(decision)
        return ReloadBroadcastResult(readyClientCount: 1, sentCount: 1, failedCount: 0)
    }

    func hasPendingBroadcast() -> Bool { continuation != nil }

    func releaseBroadcast() {
        continuation?.resume()
        continuation = nil
    }

    func deliveredDecisions() -> [ReloadDecision] { decisions }
}
