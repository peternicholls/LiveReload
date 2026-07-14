import Foundation
import LiveReloadCore

@main
enum LiveReloadBrowserHarness {
    private static let projectID = UUID(uuidString: "4EF814BF-63AA-46EC-9B87-58B91F0A459D")!

    static func main() async {
        let port = requestedPort()
        let server = ReloadServer(port: port)
        await server.start()

        let state = await server.currentState()
        guard state.phase == .listening, let listeningPort = await server.listeningPort() else {
            write(HarnessEvent(event: "startup-failed", phase: state.phase.rawValue))
            await server.stop()
            Foundation.exit(EXIT_FAILURE)
        }

        write(HarnessEvent(event: "listening", port: listeningPort, phase: state.phase.rawValue))

        while let command = readLine() {
            switch command.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "status":
                let current = await server.currentState()
                write(HarnessEvent(
                    event: "status",
                    phase: current.phase.rawValue,
                    readyClientCount: current.clientCount
                ))
            case "stylesheet":
                await deliver(
                    ReloadDecision(
                        projectID: projectID,
                        reason: .settledChanges,
                        mode: .stylesheet,
                        relativePaths: ["styles.css"]
                    ),
                    mode: "stylesheet",
                    using: server
                )
            case "full-page":
                await deliver(
                    ReloadDecision(
                        projectID: projectID,
                        reason: .settledChanges,
                        mode: .fullPage,
                        relativePaths: ["index.html"]
                    ),
                    mode: "full-page",
                    using: server
                )
            case "stop":
                await server.stop()
                write(HarnessEvent(event: "stopped", phase: ServerPhase.stopped.rawValue))
                return
            case "":
                continue
            default:
                write(HarnessEvent(event: "unknown-command"))
            }
        }

        await server.stop()
    }

    private static func deliver(
        _ decision: ReloadDecision,
        mode: String,
        using server: ReloadServer
    ) async {
        let result = await server.broadcast(decision)
        write(HarnessEvent(
            event: "broadcast",
            mode: mode,
            readyClientCount: result.readyClientCount,
            sentCount: result.sentCount,
            failedCount: result.failedCount
        ))
    }

    private static func requestedPort() -> UInt16 {
        guard let index = CommandLine.arguments.firstIndex(of: "--port"),
              CommandLine.arguments.indices.contains(index + 1),
              let port = UInt16(CommandLine.arguments[index + 1]) else {
            return 35_729
        }
        return port
    }

    private static func write(_ event: HarnessEvent) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(event) else { return }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

private struct HarnessEvent: Encodable {
    let event: String
    var mode: String?
    var port: UInt16?
    var phase: String?
    var readyClientCount: Int?
    var sentCount: Int?
    var failedCount: Int?
}
