import Darwin
import Foundation

enum SocketBrowserSessionError: Error, Equatable, Sendable {
    case closed
    case notReady
    case writeFailed
}

final class SocketBrowserSession: @unchecked Sendable, BrowserSessionControlling {
    private let id: BrowserSessionID
    private let queue: DispatchQueue
    private let lock = NSRecursiveLock()
    private let onClose: @Sendable (BrowserSessionID) -> Void
    private var descriptor: Int32
    private var source: DispatchSourceRead?
    private var state: BrowserSessionState = .connected
    private var negotiatedProtocolVersion: Int?
    private var input = Data()
    private var didClose = false

    init(
        id: BrowserSessionID,
        descriptor: Int32,
        onClose: @escaping @Sendable (BrowserSessionID) -> Void
    ) {
        self.id = id
        self.descriptor = descriptor
        self.onClose = onClose
        queue = DispatchQueue(label: "com.livereload.server.session.\(id.rawValue.uuidString)")
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [weak self] in self?.readAvailableBytes() }
        self.source = source
        source.resume()
    }

    func snapshot() async -> BrowserSessionSnapshot {
        lock.withLock {
            try! BrowserSessionSnapshot(
                id: id,
                state: state,
                negotiatedProtocolVersion: negotiatedProtocolVersion
            )
        }
    }

    func send(_ decision: ReloadDecision) async throws {
        try lock.withLock {
            guard !didClose else { throw SocketBrowserSessionError.closed }
            guard state == .ready else { throw SocketBrowserSessionError.notReady }
            let payload = try LiveReloadProtocol.encodeReload(
                path: decision.relativePaths.first ?? "",
                liveCSS: decision.mode == .stylesheet
            )
            try writeLocked(WebSocketFrameCodec.encodeServerFrame(opcode: .text, payload: payload))
        }
    }

    func close() async { closeSynchronously() }

    private func readAvailableBytes() {
        var receivedAny = false
        while true {
            var bytes = [UInt8](repeating: 0, count: 8_192)
            let count = bytes.withUnsafeMutableBytes { buffer in
                Darwin.recv(descriptor, buffer.baseAddress, buffer.count, 0)
            }
            if count > 0 {
                receivedAny = true
                let exceededLimit = lock.withLock {
                    input.append(contentsOf: bytes.prefix(count))
                    let limit = state == .connected
                        ? ProtocolLimits.maximumHeaderBytes
                        : ProtocolLimits.maximumFramePayloadBytes + 14
                    return input.count > limit
                }
                if exceededLimit {
                    closeSynchronously()
                    return
                }
                continue
            }
            if count == 0 {
                closeSynchronously()
                return
            }
            if errno == EAGAIN || errno == EWOULDBLOCK { break }
            closeSynchronously()
            return
        }
        if receivedAny { processInput() }
    }

    private func processInput() {
        lock.withLock {
            guard !didClose else { return }
            if state == .connected {
                guard input.count <= ProtocolLimits.maximumHeaderBytes else {
                    closeLocked()
                    return
                }
                let marker = Data("\r\n\r\n".utf8)
                guard let range = input.range(of: marker) else { return }
                let request = input[..<range.upperBound]
                input.removeSubrange(..<range.upperBound)
                do {
                    let upgrade = try WebSocketUpgrade.parse(Data(request))
                    try writeLocked(Data(upgrade.responseHeaders.utf8))
                    state = .negotiating
                } catch {
                    try? writeLocked(Data("HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n".utf8))
                    closeLocked()
                    return
                }
            }
            while !input.isEmpty, !didClose {
                do {
                    let decoded = try WebSocketFrameCodec.decodeClientFrame(input)
                    input.removeFirst(decoded.consumedBytes)
                    try handleLocked(decoded.frame)
                } catch WebSocketProtocolError.incompleteFrame {
                    return
                } catch {
                    closeLocked()
                    return
                }
            }
        }
    }

    private func handleLocked(_ frame: WebSocketFrame) throws {
        switch frame.opcode {
        case .text:
            guard state == .negotiating else { throw WebSocketProtocolError.unsupportedFrame }
            _ = try LiveReloadProtocol.decodeClientHello(frame.payload)
            let hello = try LiveReloadProtocol.encodeServerHello(serverName: "LiveReload")
            try writeLocked(WebSocketFrameCodec.encodeServerFrame(opcode: .text, payload: hello))
            negotiatedProtocolVersion = 7
            state = .ready
        case .ping:
            try writeLocked(WebSocketFrameCodec.encodeServerFrame(opcode: .pong, payload: frame.payload))
        case .pong:
            break
        case .close:
            try? writeLocked(WebSocketFrameCodec.encodeServerFrame(opcode: .close, payload: frame.payload))
            closeLocked()
        }
    }

    private func writeLocked(_ data: Data) throws {
        guard descriptor >= 0 else { throw SocketBrowserSessionError.closed }
        try data.withUnsafeBytes { buffer in
            var sent = 0
            while sent < data.count {
                let count = Darwin.send(descriptor, buffer.baseAddress!.advanced(by: sent), data.count - sent, 0)
                if count > 0 {
                    sent += count
                    continue
                }
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    var descriptorState = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
                    guard poll(&descriptorState, 1, 100) > 0 else { throw SocketBrowserSessionError.writeFailed }
                    continue
                }
                throw SocketBrowserSessionError.writeFailed
            }
        }
    }

    private func closeSynchronously() { lock.withLock { closeLocked() } }

    private func closeLocked() {
        guard !didClose else { return }
        didClose = true
        if state == .ready { state = .closing }
        state = .closed
        source?.cancel()
        if descriptor >= 0 {
            Darwin.shutdown(descriptor, SHUT_RDWR)
            Darwin.close(descriptor)
            descriptor = -1
        }
        onClose(id)
    }

    deinit { closeSynchronously() }
}
