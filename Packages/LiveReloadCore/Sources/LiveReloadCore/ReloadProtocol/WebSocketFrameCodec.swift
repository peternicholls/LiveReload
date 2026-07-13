import CryptoKit
import Foundation

public enum WebSocketProtocolError: Error, Equatable, Sendable {
    case incompleteFrame
    case invalidUpgrade
    case headerTooLarge
    case invalidFrame
    case unsupportedFrame
    case payloadTooLarge
}

public struct WebSocketUpgrade: Equatable, Sendable {
    public let responseHeaders: String

    public static func parse(_ data: Data) throws -> WebSocketUpgrade {
        guard data.count <= ProtocolLimits.maximumHeaderBytes else {
            throw WebSocketProtocolError.headerTooLarge
        }
        guard data.suffix(4) == Data("\r\n\r\n".utf8),
              let text = String(data: data, encoding: .utf8) else {
            throw WebSocketProtocolError.incompleteFrame
        }
        let lines = text.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw WebSocketProtocolError.invalidUpgrade
        }
        let parts = requestLine.split(separator: " ")
        guard parts.count == 3,
              parts[0] == "GET",
              parts[2] == "HTTP/1.1",
              parts[1].split(separator: "?", maxSplits: 1).first == "/livereload" else {
            throw WebSocketProtocolError.invalidUpgrade
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let separator = line.firstIndex(of: ":") else {
                throw WebSocketProtocolError.invalidUpgrade
            }
            let name = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        guard headers["upgrade"]?.lowercased() == "websocket",
              headers["connection"]?.lowercased().split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }).contains("upgrade") == true,
              headers["sec-websocket-version"] == "13",
              let key = headers["sec-websocket-key"],
              Data(base64Encoded: key)?.count == 16 else {
            throw WebSocketProtocolError.invalidUpgrade
        }

        let acceptInput = Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8)
        let accept = Data(Insecure.SHA1.hash(data: acceptInput)).base64EncodedString()
        return WebSocketUpgrade(responseHeaders:
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: \(accept)\r\n\r\n"
        )
    }
}

public enum WebSocketOpcode: UInt8, Equatable, Sendable {
    case text = 0x1
    case close = 0x8
    case ping = 0x9
    case pong = 0xA
}

public struct WebSocketFrame: Equatable, Sendable {
    public let opcode: WebSocketOpcode
    public let payload: Data

    public init(opcode: WebSocketOpcode, payload: Data) {
        self.opcode = opcode
        self.payload = payload
    }
}

public struct DecodedWebSocketFrame: Equatable, Sendable {
    public let frame: WebSocketFrame
    public let consumedBytes: Int
}

public enum WebSocketFrameCodec {
    public static func decodeClientFrame(_ data: Data) throws -> DecodedWebSocketFrame {
        guard data.count >= 2 else { throw WebSocketProtocolError.incompleteFrame }
        let first = byte(in: data, at: 0)
        let second = byte(in: data, at: 1)
        guard first & 0x80 != 0, first & 0x70 == 0 else {
            throw WebSocketProtocolError.unsupportedFrame
        }
        guard second & 0x80 != 0 else { throw WebSocketProtocolError.invalidFrame }
        guard let opcode = WebSocketOpcode(rawValue: first & 0x0f) else {
            throw WebSocketProtocolError.unsupportedFrame
        }

        var cursor = 2
        let shortLength = Int(second & 0x7f)
        let payloadLength: Int
        switch shortLength {
        case 0...125:
            payloadLength = shortLength
        case 126:
            guard data.count >= cursor + 2 else { throw WebSocketProtocolError.incompleteFrame }
            payloadLength = Int(byte(in: data, at: cursor)) << 8 | Int(byte(in: data, at: cursor + 1))
            cursor += 2
        case 127:
            guard data.count >= cursor + 8 else { throw WebSocketProtocolError.incompleteFrame }
            var length: UInt64 = 0
            for offset in cursor..<(cursor + 8) {
                let valueByte = byte(in: data, at: offset)
                guard length <= UInt64(Int.max) >> 8 else { throw WebSocketProtocolError.payloadTooLarge }
                length = length << 8 | UInt64(valueByte)
            }
            guard length <= UInt64(ProtocolLimits.maximumFramePayloadBytes) else {
                throw WebSocketProtocolError.payloadTooLarge
            }
            payloadLength = Int(length)
            cursor += 8
        default:
            throw WebSocketProtocolError.invalidFrame
        }
        guard payloadLength <= ProtocolLimits.maximumFramePayloadBytes else {
            throw WebSocketProtocolError.payloadTooLarge
        }
        if opcode != .text {
            guard payloadLength <= 125 else { throw WebSocketProtocolError.invalidFrame }
        }
        guard data.count >= cursor + 4 else { throw WebSocketProtocolError.incompleteFrame }
        let mask = (0..<4).map { byte(in: data, at: cursor + $0) }
        cursor += 4
        guard data.count >= cursor + payloadLength else { throw WebSocketProtocolError.incompleteFrame }
        let payloadStart = data.index(data.startIndex, offsetBy: cursor)
        let payloadEnd = data.index(payloadStart, offsetBy: payloadLength)
        var payload = Data(data[payloadStart..<payloadEnd])
        payload.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
            for index in 0..<payloadLength {
                bytes[index] ^= mask[index % 4]
            }
        }
        if opcode == .text, String(data: payload, encoding: .utf8) == nil {
            throw WebSocketProtocolError.invalidFrame
        }
        return DecodedWebSocketFrame(
            frame: WebSocketFrame(opcode: opcode, payload: payload),
            consumedBytes: cursor + payloadLength
        )
    }

    public static func encodeServerFrame(opcode: WebSocketOpcode, payload: Data) throws -> Data {
        guard payload.count <= ProtocolLimits.maximumFramePayloadBytes else {
            throw WebSocketProtocolError.payloadTooLarge
        }
        guard opcode == .text || payload.count <= 125 else {
            throw WebSocketProtocolError.invalidFrame
        }
        var frame = Data([0x80 | opcode.rawValue])
        appendLength(payload.count, masked: false, to: &frame)
        frame.append(payload)
        return frame
    }

    static func encodeClientFixture(opcode: WebSocketOpcode, payload: Data, mask: [UInt8]) -> Data {
        precondition(mask.count == 4)
        var frame = Data([0x80 | opcode.rawValue])
        appendLength(payload.count, masked: true, to: &frame)
        frame.append(contentsOf: mask)
        frame.append(contentsOf: payload.enumerated().map { index, byte in byte ^ mask[index % 4] })
        return frame
    }

    private static func appendLength(_ length: Int, masked: Bool, to frame: inout Data) {
        let maskBit: UInt8 = masked ? 0x80 : 0
        if length <= 125 {
            frame.append(maskBit | UInt8(length))
        } else if length <= Int(UInt16.max) {
            frame.append(maskBit | 126)
            frame.append(UInt8((length >> 8) & 0xff))
            frame.append(UInt8(length & 0xff))
        } else {
            frame.append(maskBit | 127)
            let value = UInt64(length)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((value >> UInt64(shift)) & 0xff))
            }
        }
    }

    private static func byte(in data: Data, at offset: Int) -> UInt8 {
        data[data.index(data.startIndex, offsetBy: offset)]
    }
}
