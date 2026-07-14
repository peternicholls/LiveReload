import Foundation
import LiveReloadCore

@main
enum LiveReloadBrowserHarness {
    private static let projectID = UUID(uuidString: "4EF814BF-63AA-46EC-9B87-58B91F0A459D")!

    static func main() async {
        guard let rootURL = requestedRootURL() else {
            write(HarnessEvent(event: "startup-failed", phase: "missing-root"))
            Foundation.exit(EXIT_FAILURE)
        }

        let port = requestedPort()
        let server = ReloadServer(port: port)
        await server.start()

        let state = await server.currentState()
        guard state.phase == .listening, let listeningPort = await server.listeningPort() else {
            write(HarnessEvent(event: "startup-failed", phase: state.phase.rawValue))
            await server.stop()
            Foundation.exit(EXIT_FAILURE)
        }

        let pipeline: ProjectPipeline
        do {
            pipeline = try ProjectPipeline(
                projectID: projectID,
                server: server,
                policy: ExclusionPolicy(),
                onSettled: { batch, result in
                    write(HarnessEvent(
                        event: "broadcast",
                        mode: batch.classification == .stylesheetOnly ? "stylesheet" : "full-page",
                        readyClientCount: result.readyClientCount,
                        sentCount: result.sentCount,
                        failedCount: result.failedCount
                    ))
                }
            )
        } catch {
            write(HarnessEvent(event: "startup-failed", phase: "invalid-pipeline"))
            await server.stop()
            Foundation.exit(EXIT_FAILURE)
        }

        let monitor = ProjectMonitor(
            source: FSEventsFileEventSource(),
            onSignal: { signal in
                await pipeline.receive(signal)
            },
            onStateChange: { state, reason in
                await pipeline.setMonitoringState(state, reason: reason)
            }
        )
        await monitor.start(projectID: projectID, rootURL: rootURL)
        guard await monitor.currentState() == .watching else {
            write(HarnessEvent(event: "startup-failed", phase: "monitor-failed"))
            await monitor.stop()
            await pipeline.stop()
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
            case "stop":
                await monitor.stop()
                await pipeline.stop()
                await server.stop()
                write(HarnessEvent(event: "stopped", phase: ServerPhase.stopped.rawValue))
                return
            case "":
                continue
            default:
                write(HarnessEvent(event: "unknown-command"))
            }
        }

        await monitor.stop()
        await pipeline.stop()
        await server.stop()
    }

    private static func requestedPort() -> UInt16 {
        guard let index = CommandLine.arguments.firstIndex(of: "--port"),
              CommandLine.arguments.indices.contains(index + 1),
              let port = UInt16(CommandLine.arguments[index + 1]) else {
            return 35_729
        }
        return port
    }

    private static func requestedRootURL() -> URL? {
        guard let index = CommandLine.arguments.firstIndex(of: "--root"),
              CommandLine.arguments.indices.contains(index + 1) else {
            return nil
        }
        return URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
    }

    private static func write(_ event: HarnessEvent) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(event) else { return }
        var line = data
        line.append(0x0A)
        FileHandle.standardOutput.write(line)
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
