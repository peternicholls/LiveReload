import Foundation

public struct ReloadBroadcastResult: Equatable, Sendable {
    public let readyClientCount: Int
    public let sentCount: Int
    public let failedCount: Int

    public init(readyClientCount: Int, sentCount: Int, failedCount: Int) {
        self.readyClientCount = readyClientCount
        self.sentCount = sentCount
        self.failedCount = failedCount
    }
}

public protocol ReloadServerControlling: Sendable {
    func start() async
    func stop() async
    func currentState() async -> ServerState
    func stateUpdates() async -> AsyncStream<ServerState>
    func broadcast(_ decision: ReloadDecision) async -> ReloadBroadcastResult
}

public protocol BrowserSessionControlling: Sendable {
    func snapshot() async -> BrowserSessionSnapshot
    func send(_ decision: ReloadDecision) async throws
    func close() async
}
