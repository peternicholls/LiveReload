import Darwin
import Foundation
import LiveReloadCore

private enum ProbeError: Error {
    case accessReleaseMismatch
    case clientConnectionFailed
    case clientHandshakeFailed
    case clientSessionNotReady
    case clientSessionNotReleased
    case clientWriteFailed
    case cpuSampleFailed
    case listenerDidNotRelease
    case monitorDidNotStart
    case monitorDidNotStop
    case serverDidNotStart
    case serverDidNotStop
}

private final class ReleaseCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

private final class ProtocolSevenClient: @unchecked Sendable {
    private let descriptor: Int32
    private var isClosed = false

    init(port: UInt16) throws {
        descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw ProbeError.clientConnectionFailed }
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_RCVTIMEO,
            &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )
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
        guard result == 0 else {
            Darwin.close(descriptor)
            throw ProbeError.clientConnectionFailed
        }
    }

    func negotiate() throws {
        let request =
            "GET /livereload HTTP/1.1\r\n" +
            "Host: 127.0.0.1\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Version: 13\r\n" +
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
        try write(Data(request.utf8))
        let response = try readUntil(Data("\r\n\r\n".utf8))
        guard String(data: response, encoding: .utf8)?.hasPrefix("HTTP/1.1 101") == true else {
            throw ProbeError.clientHandshakeFailed
        }

        let hello = Data(
            #"{"command":"hello","protocols":["http://livereload.com/protocols/official-7"]}"#.utf8
        )
        try write(Self.maskedTextFrame(payload: hello))
        try discardServerFrame()
    }

    func peerClosedConnection() -> Bool {
        var byte: UInt8 = 0
        let count = Darwin.recv(descriptor, &byte, 1, 0)
        return count == 0
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        Darwin.close(descriptor)
    }

    deinit { close() }

    private static func maskedTextFrame(payload: Data) -> Data {
        precondition(payload.count < 126)
        let mask: [UInt8] = [1, 2, 3, 4]
        var frame = Data([0x81, 0x80 | UInt8(payload.count)])
        frame.append(contentsOf: mask)
        for (index, byte) in payload.enumerated() {
            frame.append(byte ^ mask[index % mask.count])
        }
        return frame
    }

    private func discardServerFrame() throws {
        let header = try readExactly(2)
        guard header[0] & 0x80 != 0, header[1] & 0x80 == 0 else {
            throw ProbeError.clientHandshakeFailed
        }
        var length = Int(header[1] & 0x7f)
        if length == 126 {
            let extended = try readExactly(2)
            length = Int(extended[0]) << 8 | Int(extended[1])
        } else if length == 127 {
            let extended = try readExactly(8)
            var value: UInt64 = 0
            for byte in extended { value = value << 8 | UInt64(byte) }
            guard value <= UInt64(ProtocolLimits.maximumFramePayloadBytes) else {
                throw ProbeError.clientHandshakeFailed
            }
            length = Int(value)
        }
        _ = try readExactly(length)
    }

    private func write(_ data: Data) throws {
        try data.withUnsafeBytes { buffer in
            var sent = 0
            while sent < data.count {
                let count = Darwin.send(
                    descriptor,
                    buffer.baseAddress!.advanced(by: sent),
                    data.count - sent,
                    0
                )
                guard count > 0 else { throw ProbeError.clientWriteFailed }
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
            guard received > 0 else { throw ProbeError.clientHandshakeFailed }
            result.append(contentsOf: bytes.prefix(received))
        }
        return result
    }

    private func readUntil(_ marker: Data) throws -> Data {
        var result = Data()
        while result.range(of: marker) == nil, result.count <= ProtocolLimits.maximumHeaderBytes {
            result.append(try readExactly(1))
        }
        guard result.range(of: marker) != nil else { throw ProbeError.clientHandshakeFailed }
        return result
    }
}

private struct CPUSnapshot {
    let totalSeconds: Double

    static func capture() throws -> Self {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { throw ProbeError.cpuSampleFailed }
        let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
        let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        return Self(totalSeconds: user + system)
    }
}

private extension Duration {
    var secondsAsDouble: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1_000_000_000_000_000_000
    }
}

@main
private struct LiveReloadIdleProbe {
    private static let cleanupCycleCount = 3
    private static let warmupSeconds = 30
    private static let sampleCount = 300

    static func main() async {
        do {
            let result = try await run()
            print(result)
        } catch let error as ProbeError {
            print("result=FAIL")
            print("failure_category=\(error)")
            exit(EXIT_FAILURE)
        } catch {
            print("result=FAIL")
            print("failure_category=probe-setup")
            exit(EXIT_FAILURE)
        }
    }

    private static func run() async throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "LiveReloadIdleProbe-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let releases = ReleaseCounter()
        var monitorStops = 0
        var listenerRebinds = 0
        var sessionReleases = 0

        for _ in 0..<cleanupCycleCount {
            let monitor = ProjectMonitor(source: FSEventsFileEventSource())
            let server = ReloadServer(port: 0)
            await monitor.start(
                projectID: UUID(),
                rootURL: root,
                accessToken: ScopedAccessToken { releases.increment() }
            )
            guard await monitor.currentState() == .watching else { throw ProbeError.monitorDidNotStart }
            await server.start()
            guard (await server.currentState()).phase == .listening,
                  let port = await server.listeningPort() else {
                throw ProbeError.serverDidNotStart
            }

            let client = try ProtocolSevenClient(port: port)
            try client.negotiate()
            guard await waitForReadyClient(on: server) else { throw ProbeError.clientSessionNotReady }

            await monitor.stop()
            guard await monitor.currentState() == .stopped else { throw ProbeError.monitorDidNotStop }
            monitorStops += 1
            await server.stop()
            guard await server.currentState() == .stopped,
                  await server.listeningPort() == nil else {
                throw ProbeError.serverDidNotStop
            }
            guard client.peerClosedConnection() else { throw ProbeError.clientSessionNotReleased }
            sessionReleases += 1
            client.close()

            let rebound = ReloadServer(port: port)
            await rebound.start()
            guard (await rebound.currentState()).phase == .listening else {
                throw ProbeError.listenerDidNotRelease
            }
            listenerRebinds += 1
            await rebound.stop()
        }

        guard releases.value == cleanupCycleCount else { throw ProbeError.accessReleaseMismatch }

        let idleMonitor = ProjectMonitor(source: FSEventsFileEventSource())
        let idleServer = ReloadServer(port: 0)
        await idleMonitor.start(
            projectID: UUID(),
            rootURL: root,
            accessToken: ScopedAccessToken { releases.increment() }
        )
        guard await idleMonitor.currentState() == .watching else { throw ProbeError.monitorDidNotStart }
        await idleServer.start()
        guard (await idleServer.currentState()).phase == .listening,
              let idlePort = await idleServer.listeningPort() else {
            throw ProbeError.serverDidNotStart
        }

        try await Task.sleep(for: .seconds(warmupSeconds))
        let samples = try await collectCPUSamples(count: sampleCount)

        await idleMonitor.stop()
        guard await idleMonitor.currentState() == .stopped else { throw ProbeError.monitorDidNotStop }
        monitorStops += 1
        await idleServer.stop()
        guard await idleServer.currentState() == .stopped,
              await idleServer.listeningPort() == nil else {
            throw ProbeError.serverDidNotStop
        }
        guard releases.value == cleanupCycleCount + 1 else { throw ProbeError.accessReleaseMismatch }

        let finalRebind = ReloadServer(port: idlePort)
        await finalRebind.start()
        guard (await finalRebind.currentState()).phase == .listening else {
            throw ProbeError.listenerDidNotRelease
        }
        listenerRebinds += 1
        await finalRebind.stop()

        let mean = samples.reduce(0, +) / Double(samples.count)
        let peak = samples.max() ?? 0
        guard mean < 1 else { throw ProbeError.cpuSampleFailed }

        var lines = [
            "result=PASS",
            "measurement=process-getrusage-delta",
            "warmup_seconds=\(warmupSeconds)",
            "sample_interval_seconds=1",
            "sample_count=\(samples.count)",
            "mean_cpu_percent=\(format(mean))",
            "peak_cpu_percent=\(format(peak))",
            "cleanup_cycles=\(cleanupCycleCount)",
            "monitor_stops=\(monitorStops)",
            "scoped_access_releases=\(releases.value)",
            "listener_rebinds=\(listenerRebinds)",
            "ready_session_releases=\(sessionReleases)",
        ]
        for (offset, sample) in samples.enumerated() {
            lines.append(String(format: "sample_%03d_cpu_percent=%@", offset + 1, format(sample)))
        }
        return lines.joined(separator: "\n")
    }

    private static func waitForReadyClient(on server: ReloadServer) async -> Bool {
        for _ in 0..<100 {
            if (await server.currentState()).clientCount == 1 { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

    private static func collectCPUSamples(count: Int) async throws -> [Double] {
        let clock = ContinuousClock()
        var priorCPU = try CPUSnapshot.capture()
        var priorTime = clock.now
        var samples: [Double] = []
        samples.reserveCapacity(count)

        for _ in 0..<count {
            try await Task.sleep(for: .seconds(1))
            let currentTime = clock.now
            let currentCPU = try CPUSnapshot.capture()
            let wallSeconds = priorTime.duration(to: currentTime).secondsAsDouble
            guard wallSeconds > 0 else { throw ProbeError.cpuSampleFailed }
            let cpuSeconds = max(0, currentCPU.totalSeconds - priorCPU.totalSeconds)
            samples.append(cpuSeconds / wallSeconds * 100)
            priorCPU = currentCPU
            priorTime = currentTime
        }
        return samples
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}
