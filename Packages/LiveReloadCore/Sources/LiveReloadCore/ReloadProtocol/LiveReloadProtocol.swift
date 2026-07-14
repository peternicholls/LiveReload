import Foundation

public enum ProtocolLimits {
    public static let maximumHeaderBytes = 16 * 1_024
    public static let maximumFramePayloadBytes = 64 * 1_024
    public static let maximumMessageBytes = 64 * 1_024
    public static let maximumRelativePathBytes = 4 * 1_024
    public static let maximumClients = 32
    public static let negotiationDeadlineMilliseconds = 2_000
}

public enum ReloadProtocolError: Error, Equatable, Sendable {
    case messageTooLarge
    case invalidMessage
    case unsupportedCommand
    case unsupportedProtocol
    case invalidRelativePath
}

public struct ClientHello: Equatable, Sendable {
    public let protocols: [String]

    public init(protocols: [String]) {
        self.protocols = protocols
    }
}

public enum LiveReloadProtocol {
    public static let officialProtocol7 = "http://livereload.com/protocols/official-7"

    public static func decodeClientHello(_ data: Data) throws -> ClientHello {
        guard data.count <= ProtocolLimits.maximumMessageBytes else {
            throw ReloadProtocolError.messageTooLarge
        }
        let message: HelloMessage
        do {
            message = try JSONDecoder().decode(HelloMessage.self, from: data)
        } catch {
            throw ReloadProtocolError.invalidMessage
        }
        guard message.command == "hello" else {
            throw ReloadProtocolError.unsupportedCommand
        }
        guard message.protocols.contains(officialProtocol7) else {
            throw ReloadProtocolError.unsupportedProtocol
        }
        return ClientHello(protocols: message.protocols)
    }

    public static func encodeServerHello(serverName: String) throws -> Data {
        let safeName = String(serverName.prefix(120))
        return try encode(HelloMessage(
            command: "hello",
            protocols: [officialProtocol7],
            serverName: safeName
        ))
    }

    public static func encodeReload(path: String, liveCSS: Bool) throws -> Data {
        guard let bytes = path.data(using: .utf8),
              bytes.count <= ProtocolLimits.maximumRelativePathBytes,
              !path.hasPrefix("/"),
              !path.split(separator: "/", omittingEmptySubsequences: false).contains("..") else {
            throw ReloadProtocolError.invalidRelativePath
        }
        return try encode(ReloadMessage(
            command: "reload",
            path: path,
            liveCSS: liveCSS,
            liveImg: false,
            reloadMissingCSS: true
        ))
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let data = try JSONEncoder().encode(value)
        guard data.count <= ProtocolLimits.maximumMessageBytes else {
            throw ReloadProtocolError.messageTooLarge
        }
        return data
    }
}

private struct HelloMessage: Codable {
    let command: String
    let protocols: [String]
    var serverName: String?

    init(command: String, protocols: [String], serverName: String? = nil) {
        self.command = command
        self.protocols = protocols
        self.serverName = serverName
    }
}

private struct ReloadMessage: Encodable {
    let command: String
    let path: String
    let liveCSS: Bool
    let liveImg: Bool
    let reloadMissingCSS: Bool
}
