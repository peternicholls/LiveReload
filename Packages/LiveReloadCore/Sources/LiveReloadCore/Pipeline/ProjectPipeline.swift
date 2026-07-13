import Foundation

public actor ProjectPipeline {
    private let projectID: UUID
    private let server: any ReloadServerControlling
    private let batcher: ChangeBatcher
    private var monitoringState: MonitoringRuntimeState = .stopped
    private var recoveryReason: MonitoringRecoveryReason?
    private var latestBatch: ChangeBatch?
    private var latestBroadcast: ReloadBroadcastResult?
    private var completedBroadcastCount = 0

    public init(
        projectID: UUID,
        server: any ReloadServerControlling,
        policy: ExclusionPolicy,
        clock: any ReloadClock = ContinuousReloadClock(),
        settlingInterval: Duration = ChangeBatcher.defaultSettlingInterval
    ) throws {
        self.projectID = projectID
        self.server = server
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
        if state != .watching { await batcher.cancel() }
    }

    public func receive(_ signal: FileChangeSignal) async {
        guard monitoringState == .watching, signal.projectID == projectID else { return }
        await batcher.submit(signal) { [weak self] batch in
            await self?.broadcast(batch)
        }
    }

    @discardableResult
    public func manualReload() async -> ReloadBroadcastResult? {
        guard monitoringState == .watching else { return nil }
        let result = await server.broadcast(.manual(projectID: projectID))
        latestBroadcast = result
        completedBroadcastCount += 1
        return result
    }

    public func stop() async {
        monitoringState = .stopped
        recoveryReason = nil
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
        latestBatch = batch
        let result = await server.broadcast(ReloadDecision(batch: batch))
        latestBroadcast = result
        completedBroadcastCount += 1
    }
}
