import Foundation

final class FileEventSignalBuffer: @unchecked Sendable {
    static let maximumCapacity = 20_000

    enum YieldOutcome: Equatable, Sendable {
        case accepted
        case overflowed
        case terminated
    }

    private let projectID: UUID
    private let stream: AsyncStream<FileChangeSignal>
    private let continuation: AsyncStream<FileChangeSignal>.Continuation
    private let lock = NSLock()
    private var isFinished = false

    init(projectID: UUID, capacity: Int) {
        self.projectID = projectID
        let pair = AsyncStream<FileChangeSignal>.makeStream(
            bufferingPolicy: .bufferingNewest(min(max(1, capacity), Self.maximumCapacity))
        )
        stream = pair.stream
        continuation = pair.continuation
    }

    func signals() -> AsyncStream<FileChangeSignal> { stream }

    @discardableResult
    func yield(_ signal: FileChangeSignal) -> YieldOutcome {
        lock.withLock {
            guard !isFinished else { return .terminated }
            switch continuation.yield(signal) {
            case .enqueued:
                return .accepted
            case .dropped:
                _ = continuation.yield(.recovery(
                    projectID: projectID,
                    reason: .eventsDropped,
                    sequence: signal.sequence
                ))
                continuation.finish()
                isFinished = true
                return .overflowed
            case .terminated:
                isFinished = true
                return .terminated
            @unknown default:
                continuation.finish()
                isFinished = true
                return .terminated
            }
        }
    }

    func finish() {
        lock.withLock {
            guard !isFinished else { return }
            isFinished = true
            continuation.finish()
        }
    }
}
