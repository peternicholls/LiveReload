import Foundation

public actor FakeFileEventSource: FileEventSource {
    private var streams: [FakeFileEventStream] = []

    public init() {}

    public func makeStream(projectID: UUID, rootURL: URL) async throws -> any FileEventStream {
        let stream = FakeFileEventStream(projectID: projectID, rootURL: rootURL)
        streams.append(stream)
        return stream
    }

    public func creationCount() -> Int { streams.count }
    public func latestStream() -> FakeFileEventStream? { streams.last }
}

public actor FakeFileEventStream: FileEventStream {
    public let projectID: UUID
    public let rootURL: URL
    private let stream: AsyncStream<FileChangeSignal>
    private let continuation: AsyncStream<FileChangeSignal>.Continuation
    private var stopped = false

    public init(projectID: UUID, rootURL: URL) {
        self.projectID = projectID
        self.rootURL = rootURL
        let pair = AsyncStream<FileChangeSignal>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
    }

    public func signals() -> AsyncStream<FileChangeSignal> { stream }

    public func emit(_ signal: FileChangeSignal) {
        guard !stopped else { return }
        continuation.yield(signal)
    }

    public func stop() {
        guard !stopped else { return }
        stopped = true
        continuation.finish()
    }

    public func isStopped() -> Bool { stopped }
}
