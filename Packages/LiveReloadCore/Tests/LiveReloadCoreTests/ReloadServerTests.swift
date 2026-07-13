import Darwin
import Foundation
import Testing
@testable import LiveReloadCore

@Suite("Owned loopback reload server", .serialized)
struct ReloadServerTests {
    @Test("valid route and protocol negotiation enable reload delivery")
    func handshakeAndReload() async throws {
        let server = ReloadServer(port: 0)
        await server.start()
        defer { Task { await server.stop() } }
        let port = try #require(await server.listeningPort())
        let client = try RawWebSocketClient(port: port)
        defer { client.close() }

        try client.upgrade(path: "/livereload?snipver=1")
        try client.sendClientFrame(
            opcode: .text,
            payload: Data(#"{"command":"hello","protocols":["http://livereload.com/protocols/official-7"]}"#.utf8)
        )
        let hello = try client.receiveServerFrame()
        #expect(hello.opcode == .text)
        #expect(String(data: hello.payload, encoding: .utf8)?.contains(#""command":"hello""#) == true)
        await eventually { (await server.currentState()).clientCount == 1 }

        let result = await server.broadcast(.manual(projectID: UUID()))
        let reload = try client.receiveServerFrame()
        #expect(result == ReloadBroadcastResult(readyClientCount: 1, sentCount: 1, failedCount: 0))
        #expect(String(data: reload.payload, encoding: .utf8)?.contains(#""command":"reload""#) == true)
    }

    @Test("state updates report listener and ready-client changes without polling")
    func stateUpdates() async throws {
        let server = ReloadServer(port: 0)
        let updates = await server.stateUpdates()
        let collector = Task { () -> [ServerState] in
            var values: [ServerState] = []
            for await value in updates {
                values.append(value)
                if values.contains(where: { $0.clientCount == 1 }) { break }
            }
            return values
        }
        await server.start()
        defer { Task { await server.stop() } }
        let client = try RawWebSocketClient(port: try #require(await server.listeningPort()))
        defer { client.close() }
        try client.upgrade(path: "/livereload")
        try client.sendClientFrame(
            opcode: .text,
            payload: Data(#"{"command":"hello","protocols":["http://livereload.com/protocols/official-7"]}"#.utf8)
        )
        _ = try client.receiveServerFrame()

        let states = await collector.value
        let noClients = try ServerState.listening(clientCount: 0)
        let oneClient = try ServerState.listening(clientCount: 1)
        #expect(states.first == ServerState.stopped)
        #expect(states.contains(ServerState.starting))
        #expect(states.contains(noClients))
        #expect(states.last == oneClient)
    }

    @Test("incorrect endpoint is rejected without registering a client")
    func endpointRejection() async throws {
        let server = ReloadServer(port: 0)
        await server.start()
        defer { Task { await server.stop() } }
        let client = try RawWebSocketClient(port: try #require(await server.listeningPort()))
        defer { client.close() }

        #expect(throws: RawClientError.self) { try client.upgrade(path: "/other") }
        await eventually { (await server.currentState()).clientCount == 0 }
    }

    @Test("malformed third client cannot disrupt two ready clients")
    func malformedClientIsolation() async throws {
        let server = ReloadServer(port: 0)
        await server.start()
        defer { Task { await server.stop() } }
        let port = try #require(await server.listeningPort())
        let first = try RawWebSocketClient(port: port)
        let second = try RawWebSocketClient(port: port)
        let malformed = try RawWebSocketClient(port: port)
        defer { first.close(); second.close(); malformed.close() }
        for client in [first, second, malformed] { try client.upgrade(path: "/livereload") }
        for client in [first, second] {
            try client.sendClientFrame(
                opcode: .text,
                payload: Data(#"{"command":"hello","protocols":["http://livereload.com/protocols/official-7"]}"#.utf8)
            )
            _ = try client.receiveServerFrame()
        }
        try malformed.sendUnmaskedText("invalid")
        await eventually { (await server.currentState()).clientCount == 2 }

        let result = await server.broadcast(.manual(projectID: UUID()))
        #expect(result.sentCount == 2)
        #expect(try first.receiveServerFrame().opcode == .text)
        #expect(try second.receiveServerFrame().opcode == .text)
    }

    @Test("port conflict is retryable and restart releases the listener")
    func conflictAndRestart() async throws {
        let first = ReloadServer(port: 0)
        await first.start()
        let port = try #require(await first.listeningPort())
        let conflicting = ReloadServer(port: port)
        await conflicting.start()
        #expect((await conflicting.currentState()).phase == .portConflict)

        await first.stop()
        await conflicting.start()
        #expect((await conflicting.currentState()).phase == .listening)
        await conflicting.stop()
        await conflicting.start()
        #expect((await conflicting.currentState()).phase == .listening)
        await conflicting.stop()
    }

    @Test("oversized declared payload closes only that client")
    func oversizedPayload() async throws {
        let server = ReloadServer(port: 0)
        await server.start()
        defer { Task { await server.stop() } }
        let client = try RawWebSocketClient(port: try #require(await server.listeningPort()))
        defer { client.close() }
        try client.upgrade(path: "/livereload")
        let oversizedLength = UInt64(ProtocolLimits.maximumFramePayloadBytes + 1)
        var frame = Data([0x81, 0xff])
        for shift in stride(from: 56, through: 0, by: -8) {
            frame.append(UInt8((oversizedLength >> UInt64(shift)) & 0xff))
        }
        frame.append(contentsOf: [1, 2, 3, 4])
        try client.sendRaw(frame)

        #expect(throws: RawClientError.self) { try client.receiveServerFrame() }
        #expect((await server.currentState()).phase == .listening)
    }

    @Test("oversized upgrade headers close only that client")
    func oversizedUpgradeHeaders() async throws {
        let server = ReloadServer(port: 0)
        await server.start()
        defer { Task { await server.stop() } }
        let client = try RawWebSocketClient(port: try #require(await server.listeningPort()))
        defer { client.close() }

        try client.sendRaw(Data(repeating: UInt8(ascii: "A"), count: ProtocolLimits.maximumHeaderBytes + 1))

        #expect(throws: RawClientError.self) { try client.receiveServerFrame() }
        #expect((await server.currentState()).phase == .listening)
    }

    @Test("the ready-client registry stays within its documented ceiling")
    func clientLimit() async throws {
        let server = ReloadServer(port: 0)
        await server.start()
        defer { Task { await server.stop() } }
        let port = try #require(await server.listeningPort())
        var clients: [RawWebSocketClient] = []
        defer { clients.forEach { $0.close() } }

        for _ in 0..<ProtocolLimits.maximumClients {
            let client = try RawWebSocketClient(port: port)
            try client.upgrade(path: "/livereload")
            try client.sendClientFrame(
                opcode: .text,
                payload: Data(#"{"command":"hello","protocols":["http://livereload.com/protocols/official-7"]}"#.utf8)
            )
            _ = try client.receiveServerFrame()
            clients.append(client)
        }
        await eventually { (await server.currentState()).clientCount == ProtocolLimits.maximumClients }

        let rejected = try RawWebSocketClient(port: port)
        defer { rejected.close() }
        #expect(throws: RawClientError.self) { try rejected.upgrade(path: "/livereload") }
        #expect((await server.currentState()).clientCount == ProtocolLimits.maximumClients)
    }

    @Test("ping receives pong and close removes the session")
    func pingAndClose() async throws {
        let server = ReloadServer(port: 0)
        await server.start()
        defer { Task { await server.stop() } }
        let client = try RawWebSocketClient(port: try #require(await server.listeningPort()))
        defer { client.close() }
        try client.upgrade(path: "/livereload")
        try client.sendClientFrame(
            opcode: .text,
            payload: Data(#"{"command":"hello","protocols":["http://livereload.com/protocols/official-7"]}"#.utf8)
        )
        _ = try client.receiveServerFrame()
        try client.sendClientFrame(opcode: .ping, payload: Data("ok".utf8))
        #expect(try client.receiveServerFrame() == WebSocketFrame(opcode: .pong, payload: Data("ok".utf8)))
        try client.sendClientFrame(opcode: .close, payload: Data())
        _ = try? client.receiveServerFrame()
        await eventually { (await server.currentState()).clientCount == 0 }
    }

    @Test("closing a session while its read source is active owns and closes the descriptor once")
    func closeDuringRead() async throws {
        var descriptors: [Int32] = [-1, -1]
        #expect(Darwin.socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0)
        let peer = descriptors[1]
        defer { if peer >= 0 { Darwin.close(peer) } }
        var noSignal: Int32 = 1
        setsockopt(peer, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        let closes = LockedCounter()
        let session = SocketBrowserSession(
            id: BrowserSessionID(),
            descriptor: descriptors[0],
            onReady: { _ in },
            onClose: { _ in closes.increment() }
        )
        let writer = Task.detached {
            let fragment = Data("GET /livereload HTTP/1.1\r\n".utf8)
            for _ in 0..<1_000 {
                let sent = fragment.withUnsafeBytes {
                    Darwin.send(peer, $0.baseAddress, $0.count, 0)
                }
                if sent <= 0 { break }
                await Task.yield()
            }
        }

        await Task.yield()
        await session.close()
        await session.close()
        _ = await writer.value

        #expect((await session.snapshot()).state == .closed)
        #expect(closes.value == 1)
    }

    @Test("a stalled client does not delay another ready client and cancellation bounds completed sends")
    func stalledClientIsolation() async throws {
        let stalled = ControlledBrowserSession(stalls: true)
        let fast = ControlledBrowserSession(stalls: false)
        let delivery = Task {
            await ReloadServer.deliver(
                .manual(projectID: UUID()),
                to: [stalled, fast]
            )
        }

        await eventually { await stalled.didStartSending() }
        await eventually { await fast.sendCount() == 1 }
        delivery.cancel()
        let result = await delivery.value

        #expect(result == ReloadBroadcastResult(readyClientCount: 1, sentCount: 1, failedCount: 0))
        #expect(await stalled.sendCount() == 0)
        #expect(await fast.sendCount() == 1)
    }

    @Test("closing one session during broadcast fails only that delivery")
    func closeDuringBroadcast() async throws {
        let closing = ControlledBrowserSession(stalls: true)
        let fast = ControlledBrowserSession(stalls: false)
        let delivery = Task {
            await ReloadServer.deliver(
                .manual(projectID: UUID()),
                to: [closing, fast]
            )
        }

        await eventually { await closing.didStartSending() }
        await closing.close()
        let result = await delivery.value

        #expect(result == ReloadBroadcastResult(readyClientCount: 2, sentCount: 1, failedCount: 1))
        #expect(await closing.sendCount() == 0)
        #expect(await fast.sendCount() == 1)
    }

    @Test("cancelling a bounded broadcast prevents sessions outside the active delivery window")
    func broadcastCancellationStopsQueuedClients() async throws {
        let active = (0..<4).map { _ in ControlledBrowserSession(stalls: true) }
        let queued = ControlledBrowserSession(stalls: false)
        let delivery = Task {
            await ReloadServer.deliver(
                .manual(projectID: UUID()),
                to: active + [queued]
            )
        }

        await eventually {
            for session in active where await !session.didStartSending() { return false }
            return true
        }
        delivery.cancel()
        let result = await delivery.value

        #expect(result == ReloadBroadcastResult(readyClientCount: 0, sentCount: 0, failedCount: 0))
        #expect(await queued.sendCount() == 0)
    }
}

private actor ControlledBrowserSession: BrowserSessionControlling {
    private let id = BrowserSessionID()
    private let stalls: Bool
    private var state: BrowserSessionState = .ready
    private var startedSending = false
    private var completedSendCount = 0

    init(stalls: Bool) {
        self.stalls = stalls
    }

    func snapshot() -> BrowserSessionSnapshot {
        try! BrowserSessionSnapshot(id: id, state: state, negotiatedProtocolVersion: 7)
    }

    func send(_ decision: ReloadDecision) async throws {
        startedSending = true
        while stalls, state == .ready {
            try await Task.sleep(for: .milliseconds(1))
        }
        try Task.checkCancellation()
        guard state == .ready else { throw SocketBrowserSessionError.closed }
        completedSendCount += 1
    }

    func close() {
        state = .closed
    }

    func didStartSending() -> Bool { startedSending }
    func sendCount() -> Int { completedSendCount }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

private enum RawClientError: Error {
    case socketFailure
    case connectionFailure
    case writeFailure
    case readFailure
    case upgradeRejected
    case malformedFrame
}

private final class RawWebSocketClient: @unchecked Sendable {
    private let descriptor: Int32

    init(port: UInt16) throws {
        descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw RawClientError.socketFailure }
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else { Darwin.close(descriptor); throw RawClientError.connectionFailure }
    }

    func upgrade(path: String) throws {
        let request =
            "GET \(path) HTTP/1.1\r\n" +
            "Host: 127.0.0.1\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Version: 13\r\n" +
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
        try write(Data(request.utf8))
        let response = try readUntil(Data("\r\n\r\n".utf8))
        guard String(data: response, encoding: .utf8)?.hasPrefix("HTTP/1.1 101") == true else {
            throw RawClientError.upgradeRejected
        }
    }

    func sendClientFrame(opcode: WebSocketOpcode, payload: Data) throws {
        try write(WebSocketFrameCodec.encodeClientFixture(opcode: opcode, payload: payload, mask: [1, 2, 3, 4]))
    }

    func sendUnmaskedText(_ text: String) throws {
        try write(WebSocketFrameCodec.encodeServerFrame(opcode: .text, payload: Data(text.utf8)))
    }

    func sendRaw(_ data: Data) throws { try write(data) }

    func receiveServerFrame() throws -> WebSocketFrame {
        let header = try readExactly(2)
        guard header[0] & 0x80 != 0, header[1] & 0x80 == 0,
              let opcode = WebSocketOpcode(rawValue: header[0] & 0x0f) else {
            throw RawClientError.malformedFrame
        }
        var length = Int(header[1] & 0x7f)
        if length == 126 {
            let extended = try readExactly(2)
            length = Int(extended[0]) << 8 | Int(extended[1])
        } else if length == 127 {
            let extended = try readExactly(8)
            var value: UInt64 = 0
            for byte in extended { value = value << 8 | UInt64(byte) }
            guard value <= UInt64(ProtocolLimits.maximumFramePayloadBytes) else { throw RawClientError.malformedFrame }
            length = Int(value)
        }
        return WebSocketFrame(opcode: opcode, payload: try readExactly(length))
    }

    func close() { Darwin.close(descriptor) }

    private func write(_ data: Data) throws {
        try data.withUnsafeBytes { buffer in
            var sent = 0
            while sent < data.count {
                let count = Darwin.send(descriptor, buffer.baseAddress!.advanced(by: sent), data.count - sent, 0)
                guard count > 0 else { throw RawClientError.writeFailure }
                sent += count
            }
        }
    }

    private func readExactly(_ count: Int) throws -> Data {
        guard count > 0 else { return Data() }
        var result = Data()
        while result.count < count {
            var bytes = [UInt8](repeating: 0, count: count - result.count)
            let received = bytes.withUnsafeMutableBytes { buffer in
                Darwin.recv(descriptor, buffer.baseAddress, buffer.count, 0)
            }
            guard received > 0 else { throw RawClientError.readFailure }
            result.append(contentsOf: bytes.prefix(received))
        }
        return result
    }

    private func readUntil(_ marker: Data) throws -> Data {
        var result = Data()
        while result.range(of: marker) == nil, result.count <= ProtocolLimits.maximumHeaderBytes {
            result.append(try readExactly(1))
        }
        guard result.range(of: marker) != nil else { throw RawClientError.readFailure }
        return result
    }
}
