import Foundation

public protocol ReloadClock: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct ContinuousReloadClock: ReloadClock {
    public init() {}
    public func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}

public actor DeterministicReloadClock: ReloadClock {
    private struct Sleeper {
        let deadline: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var now: Duration = .zero
    private var sleepers: [UUID: Sleeper] = [:]

    public init() {}

    public func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        let id = UUID()
        let deadline = now + duration
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    public func advance(by duration: Duration) {
        now += duration
        let ready = sleepers.filter { $0.value.deadline <= now }
        for (id, sleeper) in ready {
            sleepers.removeValue(forKey: id)
            sleeper.continuation.resume()
        }
    }

    public func pendingSleepCount() -> Int { sleepers.count }

    private func cancel(_ id: UUID) {
        sleepers.removeValue(forKey: id)?.continuation.resume(throwing: CancellationError())
    }
}
