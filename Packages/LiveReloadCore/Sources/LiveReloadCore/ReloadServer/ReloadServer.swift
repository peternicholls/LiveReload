import Darwin
import Foundation

public actor ReloadServer: ReloadServerControlling {
    private enum DeliveryOutcome: Sendable {
        case sent
        case failed
        case skipped
        case cancelled
    }

    static let maximumConcurrentDeliveries = 4

    private let requestedPort: UInt16
    private var listener: BSDListener?
    private var sessions: [BrowserSessionID: SocketBrowserSession] = [:]
    private var phase: ServerPhase = .stopped
    private var stateContinuations: [UUID: AsyncStream<ServerState>.Continuation] = [:]

    public init(port: UInt16 = 35_729) {
        requestedPort = port
    }

    public func start() async {
        guard listener == nil else { return }
        phase = .starting
        await publishState()
        do {
            let listener = try BSDListener(port: requestedPort) { [weak self] descriptor in
                Task { await self?.accept(descriptor) }
            }
            self.listener = listener
            phase = .listening
        } catch BSDListenerError.addressInUse {
            phase = .portConflict
        } catch {
            phase = .failed
        }
        await publishState()
    }

    public func stop() async {
        listener?.stop()
        listener = nil
        let activeSessions = Array(sessions.values)
        sessions.removeAll()
        for session in activeSessions { await session.close() }
        phase = .stopped
        await publishState()
    }

    public func currentState() async -> ServerState {
        if phase != .listening {
            switch phase {
            case .stopped: return .stopped
            case .starting: return .starting
            case .portConflict: return .portConflict
            case .failed: return .failed
            case .listening: return .failed
            }
        }
        var readyCount = 0
        for session in sessions.values where await session.snapshot().isReady { readyCount += 1 }
        return (try? .listening(clientCount: readyCount)) ?? .failed
    }

    public func stateUpdates() async -> AsyncStream<ServerState> {
        let id = UUID()
        let pair = AsyncStream<ServerState>.makeStream(bufferingPolicy: .bufferingNewest(8))
        stateContinuations[id] = pair.continuation
        pair.continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStateContinuation(id) }
        }
        pair.continuation.yield(await currentState())
        return pair.stream
    }

    public func broadcast(_ decision: ReloadDecision) async -> ReloadBroadcastResult {
        await Self.deliver(decision, to: Array(sessions.values))
    }

    static func deliver(
        _ decision: ReloadDecision,
        to sessions: [any BrowserSessionControlling],
        closeFailures: Bool = true
    ) async -> ReloadBroadcastResult {
        let candidates = Array(sessions.prefix(ProtocolLimits.maximumClients))
        guard !candidates.isEmpty, !Task.isCancelled else {
            return ReloadBroadcastResult(readyClientCount: 0, sentCount: 0, failedCount: 0)
        }

        return await withTaskGroup(of: DeliveryOutcome.self) { group in
            var nextIndex = 0
            var sentCount = 0
            var failedCount = 0

            while nextIndex < min(maximumConcurrentDeliveries, candidates.count) {
                let session = candidates[nextIndex]
                nextIndex += 1
                group.addTask { await deliver(decision, to: session, closeFailures: closeFailures) }
            }

            while let outcome = await group.next() {
                switch outcome {
                case .sent: sentCount += 1
                case .failed: failedCount += 1
                case .skipped, .cancelled: break
                }

                guard !Task.isCancelled else {
                    group.cancelAll()
                    continue
                }
                if nextIndex < candidates.count {
                    let session = candidates[nextIndex]
                    nextIndex += 1
                    group.addTask { await deliver(decision, to: session, closeFailures: closeFailures) }
                }
            }

            return ReloadBroadcastResult(
                readyClientCount: sentCount + failedCount,
                sentCount: sentCount,
                failedCount: failedCount
            )
        }
    }

    private static func deliver(
        _ decision: ReloadDecision,
        to session: any BrowserSessionControlling,
        closeFailures: Bool
    ) async -> DeliveryOutcome {
        do {
            try Task.checkCancellation()
            guard await session.snapshot().isReady else { return .skipped }
            try Task.checkCancellation()
            try await session.send(decision)
            return .sent
        } catch is CancellationError {
            return .cancelled
        } catch {
            if closeFailures { await session.close() }
            return .failed
        }
    }

    public func listeningPort() -> UInt16? { listener?.port }

    private func accept(_ descriptor: Int32) {
        guard phase == .listening, sessions.count < ProtocolLimits.maximumClients else {
            Darwin.close(descriptor)
            return
        }
        let id = BrowserSessionID()
        let session = SocketBrowserSession(
            id: id,
            descriptor: descriptor,
            onReady: { [weak self] id in Task { await self?.sessionBecameReady(id) } },
            onClose: { [weak self] id in Task { await self?.removeSession(id) } }
        )
        sessions[id] = session
    }

    private func sessionBecameReady(_ id: BrowserSessionID) async {
        guard sessions[id] != nil else { return }
        await publishState()
    }

    private func removeSession(_ id: BrowserSessionID) async {
        guard sessions.removeValue(forKey: id) != nil else { return }
        await publishState()
    }

    private func publishState() async {
        let value = await currentState()
        for continuation in stateContinuations.values { continuation.yield(value) }
    }

    private func removeStateContinuation(_ id: UUID) {
        stateContinuations.removeValue(forKey: id)
    }
}
