import Foundation

public actor ProjectMonitor {
    public typealias SignalHandler = @Sendable (FileChangeSignal) async -> Void
    public typealias StateHandler = @Sendable (MonitoringRuntimeState, MonitoringRecoveryReason?) async -> Void

    private let source: any FileEventSource
    private let onSignal: SignalHandler
    private let onStateChange: StateHandler
    private var state: MonitoringRuntimeState = .stopped
    private var reason: MonitoringRecoveryReason?
    private var stream: (any FileEventStream)?
    private var signalTask: Task<Void, Never>?
    private var accessToken: ScopedAccessToken?
    private var generation: UInt64 = 0

    public init(
        source: any FileEventSource,
        onSignal: @escaping SignalHandler = { _ in },
        onStateChange: @escaping StateHandler = { _, _ in }
    ) {
        self.source = source
        self.onSignal = onSignal
        self.onStateChange = onStateChange
    }

    public func start(
        projectID: UUID,
        rootURL: URL,
        accessToken: ScopedAccessToken? = nil
    ) async {
        guard state == .stopped else { return }
        generation &+= 1
        let activeGeneration = generation
        self.accessToken = accessToken
        await transition(to: .starting)
        do {
            let stream = try await source.makeStream(projectID: projectID, rootURL: rootURL)
            guard activeGeneration == generation, state == .starting else {
                await stream.stop()
                return
            }
            self.stream = stream
            await transition(to: .watching)
            let signals = await stream.signals()
            signalTask = Task { [weak self] in
                for await signal in signals {
                    guard !Task.isCancelled else { break }
                    await self?.receive(signal, generation: activeGeneration)
                }
                await self?.streamEnded(generation: activeGeneration)
            }
        } catch {
            guard activeGeneration == generation, state == .starting else { return }
            releaseAccess()
            await transition(to: .failed, reason: .sourceFailure)
        }
    }

    public func stop() async {
        switch state {
        case .stopped:
            return
        case .watching:
            await transition(to: .stopping)
        case .starting, .recovering, .failed:
            break
        case .stopping:
            return
        }
        generation &+= 1
        signalTask?.cancel()
        signalTask = nil
        if let stream { await stream.stop() }
        stream = nil
        releaseAccess()
        await transition(to: .stopped)
    }

    public func currentState() -> MonitoringRuntimeState { state }
    public func recoveryReason() -> MonitoringRecoveryReason? { reason }

    private func receive(_ signal: FileChangeSignal, generation: UInt64) async {
        guard generation == self.generation, state == .watching else { return }
        if let recoveryReason = signal.recoveryReason {
            await enterRecovery(recoveryReason)
        } else {
            await onSignal(signal)
        }
    }

    private func streamEnded(generation: UInt64) async {
        guard generation == self.generation, state == .watching else { return }
        await enterRecovery(.sourceFailure)
    }

    private func enterRecovery(_ recoveryReason: MonitoringRecoveryReason) async {
        guard state == .watching else { return }
        await transition(to: .recovering, reason: recoveryReason)
        if let stream { await stream.stop() }
        stream = nil
        releaseAccess()
    }

    private func transition(
        to next: MonitoringRuntimeState,
        reason nextReason: MonitoringRecoveryReason? = nil
    ) async {
        state = next
        reason = nextReason
        await onStateChange(next, nextReason)
    }

    private func releaseAccess() {
        accessToken?.release()
        accessToken = nil
    }
}
