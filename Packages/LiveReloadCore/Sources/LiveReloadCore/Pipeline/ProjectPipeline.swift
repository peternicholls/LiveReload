import Foundation

public actor ProjectPipeline {
    public typealias SettledHandler = @Sendable (ChangeBatch, ReloadBroadcastResult) async -> Void

    private let projectID: UUID
    private let server: any ReloadServerControlling
    private let batcher: ChangeBatcher
    private let onSettled: SettledHandler
    private var monitoringState: MonitoringRuntimeState = .stopped
    private var recoveryReason: MonitoringRecoveryReason?
    private var latestBatch: ChangeBatch?
    private var latestBroadcast: ReloadBroadcastResult?
    private var completedBroadcastCount = 0
    private var broadcastGeneration: UInt64 = 0
    private var broadcastTasks: [UUID: Task<ReloadBroadcastResult, Never>] = [:]

    public init(
        projectID: UUID,
        server: any ReloadServerControlling,
        policy: ExclusionPolicy,
        clock: any ReloadClock = ContinuousReloadClock(),
        settlingInterval: Duration = ChangeBatcher.defaultSettlingInterval,
        onSettled: @escaping SettledHandler = { _, _ in }
    ) throws {
        self.projectID = projectID
        self.server = server
        self.onSettled = onSettled
        batcher = try ChangeBatcher(
            projectID: projectID,
            policy: policy,
            clock: clock,
            settlingInterval: settlingInterval
        )
    }

    public func setMonitoringState(
        _ state: MonitoringRuntimeState,
        reason: MonitoringRecoveryReason? = nil
    ) async {
        monitoringState = state
        recoveryReason = reason
        if state != .watching {
            cancelBroadcasts()
            await batcher.cancel()
        }
    }

    public func receive(_ signal: FileChangeSignal) async {
        guard monitoringState == .watching, signal.projectID == projectID else { return }
        await batcher.submit(signal) { [weak self] batch in
            await self?.broadcast(batch)
        }
    }

    @discardableResult
    public func manualReload() async -> ReloadBroadcastResult? {
        await performBroadcast(.manual(projectID: projectID))
    }

    public func stop() async {
        monitoringState = .stopped
        recoveryReason = nil
        cancelBroadcasts()
        await batcher.cancel()
    }

    public func state() -> MonitoringRuntimeState { monitoringState }
    public func currentRecoveryReason() -> MonitoringRecoveryReason? { recoveryReason }
    public func lastSettledBatch() -> ChangeBatch? { latestBatch }
    public func lastBroadcastResult() -> ReloadBroadcastResult? { latestBroadcast }
    public func broadcastCount() -> Int { completedBroadcastCount }
    public func isSettlementScheduled() async -> Bool { await batcher.isSettlementScheduled() }

    private func broadcast(_ batch: ChangeBatch) async {
        guard monitoringState == .watching else { return }
        guard let result = await performBroadcast(ReloadDecision(batch: batch)) else { return }
        latestBatch = batch
        await onSettled(batch, result)
    }

    private func performBroadcast(_ decision: ReloadDecision) async -> ReloadBroadcastResult? {
        guard monitoringState == .watching else { return nil }
        let generation = broadcastGeneration
        let id = UUID()
        let server = server
        let task = Task {
            guard !Task.isCancelled else {
                return ReloadBroadcastResult(readyClientCount: 0, sentCount: 0, failedCount: 0)
            }
            return await server.broadcast(decision)
        }
        broadcastTasks[id] = task
        let result = await task.value
        broadcastTasks.removeValue(forKey: id)
        guard generation == broadcastGeneration,
              monitoringState == .watching,
              !task.isCancelled else { return nil }
        latestBroadcast = result
        completedBroadcastCount += 1
        return result
    }

    private func cancelBroadcasts() {
        broadcastGeneration &+= 1
        for task in broadcastTasks.values { task.cancel() }
        broadcastTasks.removeAll()
    }
}
