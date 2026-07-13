import Darwin
import Foundation

enum SocketBrowserSessionError: Error, Equatable, Sendable {
    case closed
    case notReady
    case writeFailed
}

private final class SessionSendCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.withLock { cancelled = true }
    }

    func check() throws {
        if lock.withLock({ cancelled }) { throw CancellationError() }
    }
}

final class SocketBrowserSession: @unchecked Sendable, BrowserSessionControlling {
    private let id: BrowserSessionID
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()
    private let onReady: @Sendable (BrowserSessionID) -> Void
    private let onClose: @Sendable (BrowserSessionID) -> Void

    // The session queue is the sole owner of all mutable socket state.
    private var descriptor: Int32
    private var source: DispatchSourceRead?
    private var state: BrowserSessionState = .connected
    private var negotiatedProtocolVersion: Int?
    private var input = Data()
    private var didClose = false

    init(
        id: BrowserSessionID,
        descriptor: Int32,
        onReady: @escaping @Sendable (BrowserSessionID) -> Void,
        onClose: @escaping @Sendable (BrowserSessionID) -> Void
    ) {
        self.id = id
        self.descriptor = descriptor
        self.onReady = onReady
        self.onClose = onClose
        queue = DispatchQueue(label: "com.livereload.server.session.\(id.rawValue.uuidString)")
        queue.setSpecific(key: queueKey, value: ())
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [weak self] in self?.readAvailableBytes() }
        self.source = source
        source.resume()
    }

    func snapshot() async -> BrowserSessionSnapshot {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                continuation.resume(returning: try! BrowserSessionSnapshot(
                    id: id,
                    state: state,
                    negotiatedProtocolVersion: negotiatedProtocolVersion
                ))
            }
        }
    }

    func send(_ decision: ReloadDecision) async throws {
        let cancellation = SessionSendCancellation()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                queue.async { [self] in
                    do {
                        try cancellation.check()
                        guard !didClose else { throw SocketBrowserSessionError.closed }
                        guard state == .ready else { throw SocketBrowserSessionError.notReady }
                        let payload = try LiveReloadProtocol.encodeReload(
                            path: decision.relativePaths.first ?? "",
                            liveCSS: decision.mode == .stylesheet
                        )
                        try write(
                            WebSocketFrameCodec.encodeServerFrame(opcode: .text, payload: payload),
                            cancellation: cancellation
                        )
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    func close() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                closeOwned()
                continuation.resume()
            }
        }
    }

    private func readAvailableBytes() {
        guard !didClose else { return }
        var receivedAny = false
        while true {
            var bytes = [UInt8](repeating: 0, count: 8_192)
            let count = bytes.withUnsafeMutableBytes { buffer in
                Darwin.recv(descriptor, buffer.baseAddress, buffer.count, 0)
            }
            if count > 0 {
                receivedAny = true
                input.append(contentsOf: bytes.prefix(count))
                let limit = state == .connected
                    ? ProtocolLimits.maximumHeaderBytes
                    : ProtocolLimits.maximumFramePayloadBytes + 14
                guard input.count <= limit else {
                    closeOwned()
                    return
                }
                continue
            }
            if count == 0 {
                closeOwned()
                return
            }
            if errno == EAGAIN || errno == EWOULDBLOCK { break }
            closeOwned()
            return
        }
        if receivedAny { processInput() }
    }

    private func processInput() {
        guard !didClose else { return }
        if state == .connected {
            guard input.count <= ProtocolLimits.maximumHeaderBytes else {
                closeOwned()
                return
            }
            let marker = Data("\r\n\r\n".utf8)
            guard let range = input.range(of: marker) else { return }
            let request = input[..<range.upperBound]
            input.removeSubrange(..<range.upperBound)
            do {
                let upgrade = try WebSocketUpgrade.parse(Data(request))
                try write(Data(upgrade.responseHeaders.utf8))
                state = .negotiating
            } catch {
                try? write(Data("HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n".utf8))
                closeOwned()
                return
            }
        }
        while !input.isEmpty, !didClose {
            do {
                let decoded = try WebSocketFrameCodec.decodeClientFrame(input)
                input.removeFirst(decoded.consumedBytes)
                try handle(decoded.frame)
            } catch WebSocketProtocolError.incompleteFrame {
                return
            } catch {
                closeOwned()
                return
            }
        }
    }

    private func handle(_ frame: WebSocketFrame) throws {
        switch frame.opcode {
        case .text:
            guard state == .negotiating else { throw WebSocketProtocolError.unsupportedFrame }
            _ = try LiveReloadProtocol.decodeClientHello(frame.payload)
            let hello = try LiveReloadProtocol.encodeServerHello(serverName: "LiveReload")
            try write(WebSocketFrameCodec.encodeServerFrame(opcode: .text, payload: hello))
            negotiatedProtocolVersion = 7
            state = .ready
            onReady(id)
        case .ping:
            try write(WebSocketFrameCodec.encodeServerFrame(opcode: .pong, payload: frame.payload))
        case .pong:
            break
        case .close:
            try? write(WebSocketFrameCodec.encodeServerFrame(opcode: .close, payload: frame.payload))
            closeOwned()
        }
    }

    private func write(_ data: Data, cancellation: SessionSendCancellation? = nil) throws {
        guard descriptor >= 0 else { throw SocketBrowserSessionError.closed }
        var wroteBytes = false
        do {
            try data.withUnsafeBytes { buffer in
                var sent = 0
                while sent < data.count {
                    try cancellation?.check()
                    let count = Darwin.send(
                        descriptor,
                        buffer.baseAddress!.advanced(by: sent),
                        data.count - sent,
                        0
                    )
                    if count > 0 {
                        wroteBytes = true
                        sent += count
                        continue
                    }
                    if errno == EAGAIN || errno == EWOULDBLOCK {
                        var descriptorState = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
                        guard poll(&descriptorState, 1, 100) > 0 else {
                            try cancellation?.check()
                            throw SocketBrowserSessionError.writeFailed
                        }
                        continue
                    }
                    throw SocketBrowserSessionError.writeFailed
                }
            }
        } catch is CancellationError where wroteBytes {
            closeOwned()
            throw CancellationError()
        }
    }

    private func closeOwned() {
        guard !didClose else { return }
        didClose = true
        if state == .ready { state = .closing }
        state = .closed
        source?.cancel()
        source = nil
        if descriptor >= 0 {
            Darwin.shutdown(descriptor, SHUT_RDWR)
            Darwin.close(descriptor)
            descriptor = -1
        }
        onClose(id)
    }

    deinit {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            closeOwned()
        } else {
            queue.sync { closeOwned() }
        }
    }
}
