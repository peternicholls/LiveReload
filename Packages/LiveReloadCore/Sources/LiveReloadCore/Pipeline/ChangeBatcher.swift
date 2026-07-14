import Foundation

public enum ChangeBatcherError: Error, Equatable, Sendable {
    case settlingIntervalOutOfRange
}

public actor ChangeBatcher {
    public static let defaultSettlingInterval: Duration = .milliseconds(250)
    public typealias BatchHandler = @Sendable (ChangeBatch) async -> Void

    private let projectID: UUID
    private let policy: ExclusionPolicy
    private let clock: any ReloadClock
    private let settlingInterval: Duration
    private var orderedPaths: [String] = []
    private var paths: Set<String> = []
    private var settleTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var scheduledGeneration: UInt64?

    public init(
        projectID: UUID,
        policy: ExclusionPolicy,
        clock: any ReloadClock = ContinuousReloadClock(),
        settlingInterval: Duration = ChangeBatcher.defaultSettlingInterval
    ) throws {
        guard settlingInterval >= .milliseconds(100), settlingInterval <= .milliseconds(500) else {
            throw ChangeBatcherError.settlingIntervalOutOfRange
        }
        self.projectID = projectID
        self.policy = policy
        self.clock = clock
        self.settlingInterval = settlingInterval
    }

    public func submit(_ signal: FileChangeSignal, onSettled: @escaping BatchHandler) {
        guard signal.projectID == projectID else { return }
        if signal.recoveryReason != nil {
            cancel()
            return
        }
        guard let relativePath = signal.relativePath else { return }
        guard case .included(let normalizedPath) = policy.evaluate(relativePath: relativePath) else { return }
        if paths.insert(normalizedPath).inserted {
            guard orderedPaths.count < ChangeBatch.maximumPathCount else {
                paths.remove(normalizedPath)
                return
            }
            orderedPaths.append(normalizedPath)
        }
        generation &+= 1
        let activeGeneration = generation
        scheduledGeneration = nil
        settleTask?.cancel()
        let clock = self.clock
        let interval = settlingInterval
        settleTask = Task { [weak self] in
            do {
                await self?.markSettlementScheduled(generation: activeGeneration)
                try await clock.sleep(for: interval)
                await self?.settle(generation: activeGeneration, onSettled: onSettled)
            } catch {
                // Cancellation is the normal result of another event or stop/recovery.
            }
        }
    }

    public func cancel() {
        generation &+= 1
        settleTask?.cancel()
        settleTask = nil
        scheduledGeneration = nil
        orderedPaths.removeAll(keepingCapacity: true)
        paths.removeAll(keepingCapacity: true)
    }

    public func pendingPathCount() -> Int { orderedPaths.count }
    public func isSettlementScheduled() -> Bool { scheduledGeneration == generation }

    private func markSettlementScheduled(generation activeGeneration: UInt64) {
        guard activeGeneration == generation else { return }
        scheduledGeneration = activeGeneration
    }

    private func settle(generation activeGeneration: UInt64, onSettled: BatchHandler) async {
        guard activeGeneration == generation, !orderedPaths.isEmpty else { return }
        let batchPaths = orderedPaths
        orderedPaths.removeAll(keepingCapacity: true)
        paths.removeAll(keepingCapacity: true)
        settleTask = nil
        scheduledGeneration = nil
        let stylesheetExtensions: Set<String> = ["css", "scss", "sass", "less"]
        let classification: ChangeClassification = batchPaths.allSatisfy {
            stylesheetExtensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased())
        } ? .stylesheetOnly : .fullPage
        guard let batch = try? ChangeBatch(
            projectID: projectID,
            relativePaths: batchPaths,
            classification: classification
        ) else { return }
        await onSettled(batch)
    }
}
