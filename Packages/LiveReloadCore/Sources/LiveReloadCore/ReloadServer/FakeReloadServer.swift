import Foundation

public enum FakeBrowserSessionError: Error, Equatable, Sendable {
    case sendFailed
}

public actor FakeBrowserSession: BrowserSessionControlling {
    private let id: BrowserSessionID
    private var state: BrowserSessionState = .connected
    private var protocolVersion: Int?
    private var decisions: [ReloadDecision] = []
    private var shouldFailNextSend = false

    public init(id: BrowserSessionID = BrowserSessionID()) { self.id = id }

    public func transition(to next: BrowserSessionState, negotiatedProtocolVersion: Int? = nil) throws {
        guard state.canTransition(to: next) else { throw RuntimeModelValidationError.invalidStateTransition }
        state = next
        if let negotiatedProtocolVersion { protocolVersion = negotiatedProtocolVersion }
        _ = try BrowserSessionSnapshot(id: id, state: state, negotiatedProtocolVersion: protocolVersion)
    }

    public func snapshot() -> BrowserSessionSnapshot {
        // Fake transitions validate eagerly, so this cannot fail.
        try! BrowserSessionSnapshot(id: id, state: state, negotiatedProtocolVersion: protocolVersion)
    }

    public func send(_ decision: ReloadDecision) throws {
        guard state == .ready else { throw FakeBrowserSessionError.sendFailed }
        if shouldFailNextSend {
            shouldFailNextSend = false
            state = .failed
            throw FakeBrowserSessionError.sendFailed
        }
        decisions.append(decision)
    }

    public func close() {
        if state == .ready { state = .closing }
        if state == .closing || state == .rejected || state == .failed { state = .closed }
    }

    public func failNextSend() { shouldFailNextSend = true }
    public func receivedDecisions() -> [ReloadDecision] { decisions }
}

public actor FakeReloadServer: ReloadServerControlling {
    private var sessions: [FakeBrowserSession] = []
    private var state: ServerState = .stopped
    private var startState: ServerState

    public init(startState: ServerState = try! .listening(clientCount: 0)) {
        self.startState = startState
    }

    public func addSession(_ session: FakeBrowserSession) { sessions.append(session) }
    public func setStartState(_ state: ServerState) { startState = state }

    public func start() async {
        if startState.phase == .listening {
            state = try! .listening(clientCount: await readySessions().count)
        } else {
            state = startState
        }
    }

    public func stop() async {
        for session in sessions { await session.close() }
        state = .stopped
    }

    public func currentState() async -> ServerState {
        if state.phase == .listening {
            return try! .listening(clientCount: await readySessions().count)
        }
        return state
    }

    public func broadcast(_ decision: ReloadDecision) async -> ReloadBroadcastResult {
        let ready = await readySessions()
        var sent = 0
        var failed = 0
        for session in ready {
            do {
                try await session.send(decision)
                sent += 1
            } catch {
                failed += 1
            }
        }
        return ReloadBroadcastResult(readyClientCount: ready.count, sentCount: sent, failedCount: failed)
    }

    private func readySessions() async -> [FakeBrowserSession] {
        var result: [FakeBrowserSession] = []
        for session in sessions where await session.snapshot().isReady { result.append(session) }
        return result
    }
}
