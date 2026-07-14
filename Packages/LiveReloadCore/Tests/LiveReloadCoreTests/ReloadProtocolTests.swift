import Foundation
import Testing
@testable import LiveReloadCore

@Suite("LiveReload protocol 7")
struct ReloadProtocolTests {
    @Test("sanitized protocol fixtures remain executable golden cases")
    func protocolFixtures() throws {
        let valid = try fixtureObject("protocol-7/client-hello-valid.json")
        let unsupported = try fixtureObject("protocol-7/client-hello-unsupported.json")
        let stylesheet = try fixtureObject("protocol-7/reload-stylesheet.json")
        let validPayload = try #require(valid["payload"] as? [String: Any])
        let unsupportedPayload = try #require(unsupported["payload"] as? [String: Any])
        let stylesheetPayload = try #require(stylesheet["payload"] as? [String: Any])

        let hello = try LiveReloadProtocol.decodeClientHello(JSONSerialization.data(withJSONObject: validPayload))
        #expect(hello.protocols.contains(LiveReloadProtocol.officialProtocol7))
        #expect(throws: ReloadProtocolError.unsupportedProtocol) {
            try LiveReloadProtocol.decodeClientHello(JSONSerialization.data(withJSONObject: unsupportedPayload))
        }
        let reload = try LiveReloadProtocol.encodeReload(
            path: try #require(stylesheetPayload["path"] as? String),
            liveCSS: try #require(stylesheetPayload["liveCSS"] as? Bool)
        )
        let encoded = try #require(JSONSerialization.jsonObject(with: reload) as? [String: Any])
        #expect(encoded["path"] as? String == "assets/site.css")
        #expect(encoded["liveCSS"] as? Bool == true)
    }

    @Test("compatible hello negotiates protocol 7")
    func compatibleHello() throws {
        let input = Data(#"{"command":"hello","protocols":["http://livereload.com/protocols/official-7"]}"#.utf8)

        let hello = try LiveReloadProtocol.decodeClientHello(input)

        #expect(hello.protocols == [LiveReloadProtocol.officialProtocol7])
        let response = try LiveReloadProtocol.encodeServerHello(serverName: "LiveReload")
        let object = try #require(JSONSerialization.jsonObject(with: response) as? [String: Any])
        #expect(object["command"] as? String == "hello")
        #expect(object["protocols"] as? [String] == [LiveReloadProtocol.officialProtocol7])
    }

    @Test("unsupported commands and protocols are rejected")
    func rejectsUnsupportedNegotiation() {
        #expect(throws: ReloadProtocolError.self) {
            try LiveReloadProtocol.decodeClientHello(Data(#"{"command":"reload","protocols":[]}"#.utf8))
        }
        #expect(throws: ReloadProtocolError.self) {
            try LiveReloadProtocol.decodeClientHello(Data(#"{"command":"hello","protocols":["legacy"]}"#.utf8))
        }
    }

    @Test("reload messages preserve relative paths and classification")
    func reloadEncoding() throws {
        let stylesheet = try LiveReloadProtocol.encodeReload(path: "styles/site.css", liveCSS: true)
        let fullPage = try LiveReloadProtocol.encodeReload(path: "index.html", liveCSS: false)

        let cssObject = try #require(JSONSerialization.jsonObject(with: stylesheet) as? [String: Any])
        let htmlObject = try #require(JSONSerialization.jsonObject(with: fullPage) as? [String: Any])
        #expect(cssObject["command"] as? String == "reload")
        #expect(cssObject["path"] as? String == "styles/site.css")
        #expect(cssObject["liveCSS"] as? Bool == true)
        #expect(htmlObject["liveCSS"] as? Bool == false)
    }

    @Test("messages and paths are bounded")
    func boundedValues() {
        #expect(throws: ReloadProtocolError.self) {
            try LiveReloadProtocol.decodeClientHello(Data(repeating: 0x61, count: ProtocolLimits.maximumMessageBytes + 1))
        }
        #expect(throws: ReloadProtocolError.self) {
            try LiveReloadProtocol.encodeReload(
                path: String(repeating: "a", count: ProtocolLimits.maximumRelativePathBytes + 1),
                liveCSS: false
            )
        }
        #expect(throws: ReloadProtocolError.self) {
            try LiveReloadProtocol.encodeReload(path: "/private/source/index.html", liveCSS: false)
        }
    }
}

@Suite("WebSocket upgrade and frames")
struct WebSocketFrameTests {
    @Test("sanitized raw-frame fixtures exercise masking and control opcodes")
    func frameFixtures() throws {
        let text = try fixtureObject("raw-frame/masked-text.json")
        let ping = try fixtureObject("raw-frame/masked-ping.json")
        let unmasked = try fixtureObject("raw-frame/unmasked-client-text.json")
        let textFrame = try WebSocketFrameCodec.decodeClientFrame(Data(hex: try #require(text["frameHex"] as? String)))
        let pingFrame = try WebSocketFrameCodec.decodeClientFrame(Data(hex: try #require(ping["frameHex"] as? String)))
        #expect(textFrame.frame == WebSocketFrame(opcode: .text, payload: Data("hi".utf8)))
        #expect(pingFrame.frame.opcode == .ping)
        #expect(throws: WebSocketProtocolError.invalidFrame) {
            try WebSocketFrameCodec.decodeClientFrame(Data(hex: try #require(unmasked["frameHex"] as? String)))
        }
    }

    @Test("upgrade accepts only the local LiveReload route and loopback browser origins")
    func upgradeValidation() throws {
        let request = Data((
            "GET /livereload?snipver=1 HTTP/1.1\r\n" +
            "Host: 127.0.0.1:35729\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Version: 13\r\n" +
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
        ).utf8)

        let upgrade = try WebSocketUpgrade.parse(request)

        #expect(upgrade.responseHeaders.contains("s3pPLMBiTxaQ9kYGzzhZRbK+xOo="))

        for origin in [
            "http://127.0.0.1:35731",
            "https://127.0.0.1",
            "http://localhost:35731",
            "https://localhost"
        ] {
            var browserRequest = request
            browserRequest.insert(contentsOf: Data("Origin: \(origin)\r\n".utf8), at: browserRequest.count - 2)
            #expect(throws: Never.self) { try WebSocketUpgrade.parse(browserRequest) }
        }

        for origin in [
            "https://attacker.example",
            "null",
            "file://localhost",
            "http://user@localhost",
            "http://localhost/path",
            "http://localhost:not-a-port"
        ] {
            var hostileRequest = request
            hostileRequest.insert(contentsOf: Data("Origin: \(origin)\r\n".utf8), at: hostileRequest.count - 2)
            #expect(throws: WebSocketProtocolError.invalidUpgrade) {
                try WebSocketUpgrade.parse(hostileRequest)
            }
        }

        var duplicateOriginRequest = request
        duplicateOriginRequest.insert(
            contentsOf: Data("Origin: http://localhost\r\nOrigin: http://127.0.0.1\r\n".utf8),
            at: duplicateOriginRequest.count - 2
        )
        #expect(throws: WebSocketProtocolError.invalidUpgrade) {
            try WebSocketUpgrade.parse(duplicateOriginRequest)
        }

        var rejected = request
        rejected.replaceSubrange(4..<(4 + "/livereload".utf8.count), with: "/other".utf8)
        #expect(throws: WebSocketProtocolError.self) { try WebSocketUpgrade.parse(rejected) }
    }

    @Test("masked client text frames decode and server frames remain unmasked")
    func frameRoundTrip() throws {
        let payload = Data("hello".utf8)
        let clientFrame = WebSocketFrameCodec.encodeClientFixture(
            opcode: .text,
            payload: payload,
            mask: [0x01, 0x02, 0x03, 0x04]
        )

        let decoded = try WebSocketFrameCodec.decodeClientFrame(clientFrame)

        #expect(decoded.frame.opcode == .text)
        #expect(decoded.frame.payload == payload)
        #expect(decoded.consumedBytes == clientFrame.count)
        let serverFrame = try WebSocketFrameCodec.encodeServerFrame(opcode: .text, payload: payload)
        #expect(serverFrame[1] & 0x80 == 0)
    }

    @Test("unmasked, fragmented, oversized, and unsupported frames are rejected")
    func rejectsInvalidFrames() throws {
        let unmasked = try WebSocketFrameCodec.encodeServerFrame(opcode: .text, payload: Data("x".utf8))
        #expect(throws: WebSocketProtocolError.self) { try WebSocketFrameCodec.decodeClientFrame(unmasked) }

        var fragmented = WebSocketFrameCodec.encodeClientFixture(
            opcode: .text,
            payload: Data("x".utf8),
            mask: [1, 2, 3, 4]
        )
        fragmented[0] &= 0x7f
        #expect(throws: WebSocketProtocolError.self) { try WebSocketFrameCodec.decodeClientFrame(fragmented) }

        let oversizedHeader = Data([0x81, 0xff]) + Data(repeating: 0xff, count: 8) + Data([1, 2, 3, 4])
        #expect(throws: WebSocketProtocolError.self) { try WebSocketFrameCodec.decodeClientFrame(oversizedHeader) }

        var binary = WebSocketFrameCodec.encodeClientFixture(
            opcode: .text,
            payload: Data("x".utf8),
            mask: [1, 2, 3, 4]
        )
        binary[0] = 0x82
        #expect(throws: WebSocketProtocolError.self) { try WebSocketFrameCodec.decodeClientFrame(binary) }
    }

    @Test("incomplete frames request more bytes without allocating payload")
    func incompleteFrame() {
        #expect(throws: WebSocketProtocolError.incompleteFrame) {
            try WebSocketFrameCodec.decodeClientFrame(Data([0x81]))
        }
    }
}

private func fixtureObject(_ relativePath: String) throws -> [String: Any] {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { root.deleteLastPathComponent() }
    let url = root.appending(path: "tests/fixtures/reload-loop/\(relativePath)")
    return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
}

private extension Data {
    init(hex: String) throws {
        guard hex.count.isMultiple(of: 2) else { throw WebSocketProtocolError.invalidFrame }
        var data = Data()
        var cursor = hex.startIndex
        while cursor < hex.endIndex {
            let end = hex.index(cursor, offsetBy: 2)
            guard let byte = UInt8(hex[cursor..<end], radix: 16) else {
                throw WebSocketProtocolError.invalidFrame
            }
            data.append(byte)
            cursor = end
        }
        self = data
    }
}
