import Foundation
import Testing
@testable import LiveReloadCore

@Test func fakeEventSourceEmitsAndStopsWithoutARealFileSystemStream() async throws {
    let projectID = UUID()
    let source = FakeFileEventSource()
    let stream = try await source.makeStream(
        projectID: projectID,
        rootURL: URL(fileURLWithPath: "/tmp/fixture", isDirectory: true)
    )
    let fakeStream = try #require(stream as? FakeFileEventStream)
    let signals = await stream.signals()
    let expected = try FileChangeSignal.change(
        projectID: projectID,
        relativePath: "index.html",
        kind: .modified,
        sequence: 1
    )

    await fakeStream.emit(expected)
    var iterator = signals.makeAsyncIterator()
    #expect(await iterator.next() == expected)

    await stream.stop()
    #expect(await fakeStream.isStopped())
    #expect(await source.creationCount() == 1)
}

@Test func deterministicClockAdvancesSleepersWithoutWallClockDelay() async throws {
    let clock = DeterministicReloadClock()
    let sleeper = Task {
        try await clock.sleep(for: .milliseconds(250))
        return true
    }

    await Task.yield()
    #expect(await clock.pendingSleepCount() == 1)
    await clock.advance(by: .milliseconds(249))
    #expect(await clock.pendingSleepCount() == 1)
    await clock.advance(by: .milliseconds(1))
    #expect(try await sleeper.value)
    #expect(await clock.pendingSleepCount() == 0)
}

@Test func fakeReloadServerRecordsOneBroadcastForEveryReadySession() async throws {
    let server = FakeReloadServer()
    let first = FakeBrowserSession()
    let second = FakeBrowserSession()
    try await first.transition(to: .negotiating)
    try await first.transition(to: .ready, negotiatedProtocolVersion: 7)
    try await second.transition(to: .negotiating)
    try await second.transition(to: .ready, negotiatedProtocolVersion: 7)
    await server.addSession(first)
    await server.addSession(second)
    await server.start()

    #expect(await server.currentState() == (try ServerState.listening(clientCount: 2)))

    let decision = ReloadDecision.manual(projectID: UUID())
    let result = await server.broadcast(decision)
    #expect(result.readyClientCount == 2)
    #expect(result.sentCount == 2)
    #expect(await first.receivedDecisions() == [decision])
    #expect(await second.receivedDecisions() == [decision])

    await first.close()
    let secondResult = await server.broadcast(decision)
    #expect(secondResult.readyClientCount == 1)
    #expect(secondResult.sentCount == 1)
}

@Test func fakeReloadServerCanModelConflictAndSessionFailureInIsolation() async throws {
    let server = FakeReloadServer(startState: .portConflict)
    let valid = FakeBrowserSession()
    let failing = FakeBrowserSession()
    try await valid.transition(to: .negotiating)
    try await valid.transition(to: .ready, negotiatedProtocolVersion: 7)
    try await failing.transition(to: .negotiating)
    try await failing.transition(to: .ready, negotiatedProtocolVersion: 7)
    await failing.failNextSend()
    await server.addSession(valid)
    await server.addSession(failing)
    await server.start()

    #expect((await server.currentState()).phase == .portConflict)

    await server.setStartState(try ServerState.listening(clientCount: 0))
    await server.start()
    let decision = ReloadDecision.manual(projectID: UUID())
    let result = await server.broadcast(decision)

    #expect(result.readyClientCount == 2)
    #expect(result.sentCount == 1)
    #expect(result.failedCount == 1)
    #expect(await valid.receivedDecisions() == [decision])
    #expect((await failing.snapshot()).state == .failed)
}
