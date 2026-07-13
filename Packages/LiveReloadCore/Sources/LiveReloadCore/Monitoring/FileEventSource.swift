import Foundation

public protocol FileEventSource: Sendable {
    func makeStream(projectID: UUID, rootURL: URL) async throws -> any FileEventStream
}

public protocol FileEventStream: Sendable {
    func signals() async -> AsyncStream<FileChangeSignal>
    func stop() async
}
