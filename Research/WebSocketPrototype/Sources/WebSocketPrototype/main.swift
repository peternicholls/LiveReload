import Foundation
import Network

func log(_ text: String) {
    FileHandle.standardOutput.write(Data((text + "\n").utf8))
}

// All mutable state is confined to `queue`; Network's callback APIs require
// Sendable captures, so this prototype documents that confinement explicitly.
final class PrototypeServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "livereload.phase0.websocket")
    private let listener: NWListener
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    init(port: UInt16) throws {
        let options = NWProtocolWebSocket.Options(.version13)
        options.autoReplyPing = true
        options.maximumMessageSize = 64 * 1024
        options.setClientRequestHandler(queue) { _, _ in
            .init(status: .accept, subprotocol: nil)
        }
        let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                log("READY \(self.listener.port?.rawValue ?? 0)")
            case let .failed(error):
                fputs("FAILED \(error)\n", stderr)
                exit(2)
            default:
                break
            }
        }
    }

    func start() {
        listener.start(queue: queue)
        DispatchQueue.global().async { [weak self] in self?.readStandardInput() }
        dispatchMain()
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            if case .failed = state { self.remove(connection) }
            if case .cancelled = state { self.remove(connection) }
        }
        connection.start(queue: queue)
        receive(from: connection)
    }

    private func receive(from connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self, let connection else { return }
            defer {
                if error == nil { self.receive(from: connection) }
            }
            guard error == nil, let data, let raw = String(data: data, encoding: .utf8) else {
                self.remove(connection)
                return
            }
            guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  message["command"] as? String == "hello",
                  message["protocols"] as? [String] != nil else {
                log("INVALID \(raw)")
                return
            }
            self.sendJSON(["command": "hello", "protocols": ["http://livereload.com/protocols/official-7"], "serverName": "Phase 0 Network.framework Prototype"], to: connection)
        }
    }

    private func readStandardInput() {
        while let line = readLine() {
            guard let data = line.data(using: .utf8),
                  let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  message["command"] as? String == "reload" else {
                log("INVALID-STDIN \(line)")
                continue
            }
            queue.async { [weak self, data] in self?.broadcast(data) }
        }
    }

    private func broadcast(_ data: Data) {
        for connection in connections.values { send(data, to: connection) }
        log("BROADCAST \(connections.count)")
    }

    private func sendJSON(_ message: [String: Any], to connection: NWConnection) {
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        send(data, to: connection)
    }

    private func send(_ data: Data, to connection: NWConnection) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "phase0", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { [weak self, weak connection] error in
            if let error {
                fputs("SEND-FAILED \(error)\n", stderr)
                if let connection { self?.remove(connection) }
            }
        })
    }

    private func remove(_ connection: NWConnection) {
        connections.removeValue(forKey: ObjectIdentifier(connection))
    }
}

let port = UInt16(CommandLine.arguments.dropFirst().first ?? "35732") ?? 35732
do {
    try PrototypeServer(port: port).start()
} catch {
    fputs("FAILED \(error)\n", stderr)
    exit(2)
}
