import Darwin
import Foundation

public actor ReloadServer: ReloadServerControlling {
    private let requestedPort: UInt16
    private var listener: BSDListener?
    private var sessions: [BrowserSessionID: SocketBrowserSession] = [:]
    private var phase: ServerPhase = .stopped

    public init(port: UInt16 = 35_729) {
        requestedPort = port
    }

    public func start() async {
        guard listener == nil else { return }
        phase = .starting
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
    }

    public func stop() async {
        listener?.stop()
        listener = nil
        let activeSessions = Array(sessions.values)
        sessions.removeAll()
        for session in activeSessions { await session.close() }
        phase = .stopped
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

    public func broadcast(_ decision: ReloadDecision) async -> ReloadBroadcastResult {
        var readyCount = 0
        var sentCount = 0
        var failedCount = 0
        for session in sessions.values {
            guard await session.snapshot().isReady else { continue }
            readyCount += 1
            do {
                try await session.send(decision)
                sentCount += 1
            } catch {
                failedCount += 1
                await session.close()
            }
        }
        return ReloadBroadcastResult(
            readyClientCount: readyCount,
            sentCount: sentCount,
            failedCount: failedCount
        )
    }

    public func listeningPort() -> UInt16? { listener?.port }

    private func accept(_ descriptor: Int32) {
        guard phase == .listening, sessions.count < ProtocolLimits.maximumClients else {
            Darwin.close(descriptor)
            return
        }
        let id = BrowserSessionID()
        let session = SocketBrowserSession(id: id, descriptor: descriptor) { [weak self] id in
            Task { await self?.removeSession(id) }
        }
        sessions[id] = session
    }

    private func removeSession(_ id: BrowserSessionID) { sessions.removeValue(forKey: id) }
}
