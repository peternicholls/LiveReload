import Foundation
import Testing
@testable import LiveReloadCore

@Suite("Project monitor lifecycle")
struct ProjectMonitorTests {
    @Test("source startup failure releases access and reports failed")
    func startupFailure() async {
        let releases = ReleaseCounter()
        let monitor = ProjectMonitor(source: FailingEventSource())
        await monitor.start(
            projectID: UUID(),
            rootURL: URL(fileURLWithPath: "/tmp/missing"),
            accessToken: ScopedAccessToken { releases.increment() }
        )
        #expect(await monitor.currentState() == .failed)
        #expect(await monitor.recoveryReason() == .sourceFailure)
        #expect(releases.value == 1)
        await monitor.stop()
        #expect(await monitor.currentState() == .stopped)
    }

    @Test("stop wins when stream creation fails after suspension")
    func stopDuringSuspendedStartup() async {
        let source = ControlledFailingEventSource()
        let releases = ReleaseCounter()
        let states = StateRecorder()
        let monitor = ProjectMonitor(
            source: source,
            onStateChange: { state, _ in await states.append(state) }
        )
        let startTask = Task {
            await monitor.start(
                projectID: UUID(),
                rootURL: URL(fileURLWithPath: "/tmp/suspended"),
                accessToken: ScopedAccessToken { releases.increment() }
            )
        }
        await eventually { await source.hasPendingRequest() }
        #expect(await source.hasPendingRequest())

        await monitor.stop()
        await source.failPendingRequest()
        await startTask.value

        #expect(await monitor.currentState() == .stopped)
        #expect(await monitor.recoveryReason() == nil)
        #expect(await states.values() == [.starting, .stopped])
        #expect(releases.value == 1)
    }

    @Test("workspace FSEvents reports create, modify, rename, and delete")
    func workspaceEvents() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "LiveReloadFSEvents-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let existing = root.appending(path: "existing.txt")
        try Data("baseline".utf8).write(to: existing)
        let source = FSEventsFileEventSource(latency: 0.05)
        let projectID = UUID()
        let stream = try await source.makeStream(projectID: projectID, rootURL: root)
        let signals = await stream.signals()
        let collector = Task { () -> Set<FileChangeKind> in
            var kinds: Set<FileChangeKind> = []
            for await signal in signals {
                if let kind = signal.kind { kinds.insert(kind) }
                if kinds.isSuperset(of: Set(FileChangeKind.allCases)) { break }
            }
            return kinds
        }

        try await Task.sleep(for: .milliseconds(100))
        let original = root.appending(path: "fixture.txt")
        let renamed = root.appending(path: "renamed.txt")
        try Data("first".utf8).write(to: original)
        try await Task.sleep(for: .milliseconds(150))
        try FileHandle(forWritingTo: existing).closeAfterWriting(Data(" second".utf8))
        try await Task.sleep(for: .milliseconds(150))
        try FileManager.default.moveItem(at: original, to: renamed)
        try await Task.sleep(for: .milliseconds(150))
        try FileManager.default.removeItem(at: renamed)

        try await Task.sleep(for: .milliseconds(500))
        await stream.stop()
        let kinds = await collector.value

        #expect(kinds.isSuperset(of: Set(FileChangeKind.allCases)))
    }

    @Test("start and stop are idempotent and release owned resources")
    func idempotentLifecycle() async throws {
        let source = FakeFileEventSource()
        let releases = ReleaseCounter()
        let token = ScopedAccessToken { releases.increment() }
        let states = StateRecorder()
        let monitor = ProjectMonitor(
            source: source,
            onStateChange: { state, _ in await states.append(state) }
        )
        let projectID = UUID()

        await monitor.start(
            projectID: projectID,
            rootURL: URL(fileURLWithPath: "/tmp/fixture", isDirectory: true),
            accessToken: token
        )
        await monitor.start(
            projectID: projectID,
            rootURL: URL(fileURLWithPath: "/tmp/fixture", isDirectory: true),
            accessToken: nil
        )

        #expect(await monitor.currentState() == .watching)
        #expect(await source.creationCount() == 1)
        await monitor.stop()
        await monitor.stop()
        #expect(await monitor.currentState() == .stopped)
        #expect(releases.value == 1)
        #expect(await states.values() == [.starting, .watching, .stopping, .stopped])
    }

    @Test("root change and event loss enter recovery without forwarding a reloadable signal", arguments: [
        MonitoringRecoveryReason.rootChanged,
        .eventsDropped,
        .scanRequired,
        .folderUnavailable,
    ])
    func recovery(reason: MonitoringRecoveryReason) async throws {
        let source = FakeFileEventSource()
        let received = SignalRecorder()
        let monitor = ProjectMonitor(source: source, onSignal: { await received.append($0) })
        let projectID = UUID()
        await monitor.start(projectID: projectID, rootURL: URL(fileURLWithPath: "/tmp/fixture"))
        let stream = try #require(await source.latestStream())

        await stream.emit(.recovery(projectID: projectID, reason: reason, sequence: 10))
        await eventually { await monitor.currentState() == .recovering }

        #expect(await monitor.recoveryReason() == reason)
        #expect(await stream.isStopped())
        #expect(await received.values().isEmpty)
        await monitor.stop()
        #expect(await monitor.currentState() == .stopped)
    }

    @Test("normal create, modify, rename, and delete signals are forwarded only while watching")
    func forwardsSupportedSignals() async throws {
        let source = FakeFileEventSource()
        let received = SignalRecorder()
        let monitor = ProjectMonitor(source: source, onSignal: { await received.append($0) })
        let projectID = UUID()
        await monitor.start(projectID: projectID, rootURL: URL(fileURLWithPath: "/tmp/fixture"))
        let stream = try #require(await source.latestStream())

        for (index, kind) in FileChangeKind.allCases.enumerated() {
            await stream.emit(try .change(
                projectID: projectID,
                relativePath: "file-\(index).html",
                kind: kind,
                sequence: UInt64(index)
            ))
        }
        await eventually { await received.values().count == FileChangeKind.allCases.count }
        await monitor.stop()
        await stream.emit(try .change(projectID: projectID, relativePath: "late.html", kind: .modified, sequence: 99))

        #expect(await received.values().count == FileChangeKind.allCases.count)
    }

    @Test("bounded event buffering converts overflow into one recovery signal")
    func boundedEventBufferOverflow() async throws {
        let projectID = UUID()
        let buffer = FileEventSignalBuffer(projectID: projectID, capacity: 2)
        let signals = buffer.signals()

        #expect(buffer.yield(try .change(
            projectID: projectID,
            relativePath: "first.html",
            kind: .modified,
            sequence: 1
        )) == .accepted)
        #expect(buffer.yield(try .change(
            projectID: projectID,
            relativePath: "second.html",
            kind: .modified,
            sequence: 2
        )) == .accepted)
        #expect(buffer.yield(try .change(
            projectID: projectID,
            relativePath: "third.html",
            kind: .modified,
            sequence: 3
        )) == .overflowed)
        #expect(buffer.yield(try .change(
            projectID: projectID,
            relativePath: "late.html",
            kind: .modified,
            sequence: 4
        )) == .terminated)

        var received: [FileChangeSignal] = []
        for await signal in signals { received.append(signal) }

        #expect(received.count <= 2)
        #expect(received.filter { $0.recoveryReason == .eventsDropped }.count == 1)
        #expect(received.last?.recoveryReason == .eventsDropped)
        #expect(received.last?.sequence == 3)
    }
}

private extension FileHandle {
    func closeAfterWriting(_ data: Data) throws {
        defer { try? close() }
        try seekToEnd()
        try write(contentsOf: data)
    }
}

@Suite("Change batcher")
struct ChangeBatcherTests {
    @Test("a burst settles once with first-seen order and conservative classification")
    func orderedBatch() async throws {
        let clock = DeterministicReloadClock()
        let batches = BatchRecorder()
        let projectID = UUID()
        let batcher = try ChangeBatcher(projectID: projectID, policy: ExclusionPolicy(), clock: clock)

        for (sequence, path) in ["styles/site.css", "index.html", "styles/site.css"].enumerated() {
            await batcher.submit(try .change(
                projectID: projectID,
                relativePath: path,
                kind: .modified,
                sequence: UInt64(sequence)
            )) { await batches.append($0) }
        }
        await eventually {
            let scheduled = await batcher.isSettlementScheduled()
            let sleepers = await clock.pendingSleepCount()
            return scheduled && sleepers == 1
        }
        await clock.advance(by: .milliseconds(249))
        #expect(await batches.values().isEmpty)
        await clock.advance(by: .milliseconds(1))
        await eventually { await batches.values().count == 1 }

        let batch = try #require(await batches.values().first)
        #expect(batch.relativePaths == ["styles/site.css", "index.html"])
        #expect(batch.classification == .fullPage)
    }

    @Test("settling accepts the documented boundaries and rejects values outside them")
    func settlingBoundaries() async throws {
        for interval in [Duration.milliseconds(100), .milliseconds(500)] {
            let clock = DeterministicReloadClock()
            let batches = BatchRecorder()
            let projectID = UUID()
            let batcher = try ChangeBatcher(
                projectID: projectID,
                policy: ExclusionPolicy(),
                clock: clock,
                settlingInterval: interval
            )
            await batcher.submit(try .change(
                projectID: projectID,
                relativePath: "index.html",
                kind: .modified,
                sequence: 1
            )) { await batches.append($0) }
            await eventually { await clock.pendingSleepCount() == 1 }
            await clock.advance(by: interval - .milliseconds(1))
            #expect(await batches.values().isEmpty)
            await clock.advance(by: .milliseconds(1))
            await eventually { await batches.values().count == 1 }
        }

        #expect(throws: ChangeBatcherError.settlingIntervalOutOfRange) {
            try ChangeBatcher(
                projectID: UUID(),
                policy: ExclusionPolicy(),
                settlingInterval: .milliseconds(99)
            )
        }
        #expect(throws: ChangeBatcherError.settlingIntervalOutOfRange) {
            try ChangeBatcher(
                projectID: UUID(),
                policy: ExclusionPolicy(),
                settlingInterval: .milliseconds(501)
            )
        }
    }

    @Test("stylesheet-only and excluded-only bursts classify correctly")
    func filteringAndStylesheet() async throws {
        let clock = DeterministicReloadClock()
        let batches = BatchRecorder()
        let projectID = UUID()
        let batcher = try ChangeBatcher(
            projectID: projectID,
            policy: ExclusionPolicy(userPatterns: ["generated/"]),
            clock: clock
        )
        for (sequence, path) in ["node_modules/x.js", "generated/app.js", "styles/a.css", "styles/b.scss"].enumerated() {
            await batcher.submit(try .change(
                projectID: projectID,
                relativePath: path,
                kind: .modified,
                sequence: UInt64(sequence)
            )) { await batches.append($0) }
        }
        await eventually {
            let scheduled = await batcher.isSettlementScheduled()
            let sleepers = await clock.pendingSleepCount()
            return scheduled && sleepers == 1
        }
        await clock.advance(by: .milliseconds(250))
        await eventually { await batches.values().count == 1 }
        #expect(await batches.values().first?.relativePaths == ["styles/a.css", "styles/b.scss"])
        #expect(await batches.values().first?.classification == .stylesheetOnly)
    }

    @Test("recovery and stop cancel pending work")
    func cancellation() async throws {
        let clock = DeterministicReloadClock()
        let batches = BatchRecorder()
        let projectID = UUID()
        let batcher = try ChangeBatcher(projectID: projectID, policy: ExclusionPolicy(), clock: clock)
        await batcher.submit(try .change(projectID: projectID, relativePath: "index.html", kind: .modified, sequence: 1)) {
            await batches.append($0)
        }
        await batcher.submit(.recovery(projectID: projectID, reason: .eventsDropped, sequence: 2)) {
            await batches.append($0)
        }
        await clock.advance(by: .seconds(1))
        #expect(await batches.values().isEmpty)
        #expect(await batcher.pendingPathCount() == 0)
    }

    @Test("ten thousand noisy events remain bounded and emit one decision")
    func tenThousandEvents() async throws {
        let clock = DeterministicReloadClock()
        let batches = BatchRecorder()
        let projectID = UUID()
        let batcher = try ChangeBatcher(projectID: projectID, policy: ExclusionPolicy(), clock: clock)
        for sequence in 0..<10_000 {
            let path = sequence.isMultiple(of: 2) ? "index.html" : "node_modules/pkg/file.js"
            await batcher.submit(try .change(
                projectID: projectID,
                relativePath: path,
                kind: .modified,
                sequence: UInt64(sequence)
            )) { await batches.append($0) }
        }
        await eventually(timeoutIterations: 20_000) {
            let scheduled = await batcher.isSettlementScheduled()
            let sleepers = await clock.pendingSleepCount()
            return scheduled && sleepers == 1
        }
        await clock.advance(by: .milliseconds(250))
        await eventually { await batches.values().count == 1 }
        #expect(await batches.values().first?.relativePaths == ["index.html"])
        #expect(await batcher.pendingPathCount() == 0)
    }
}

private final class ReleaseCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

private struct FailingEventSource: FileEventSource {
    func makeStream(projectID: UUID, rootURL: URL) async throws -> any FileEventStream {
        throw FSEventsSourceError.streamCreationFailed
    }
}

private actor ControlledFailingEventSource: FileEventSource {
    private var continuation: CheckedContinuation<any FileEventStream, any Error>?

    func makeStream(projectID: UUID, rootURL: URL) async throws -> any FileEventStream {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func hasPendingRequest() -> Bool { continuation != nil }

    func failPendingRequest() {
        continuation?.resume(throwing: FSEventsSourceError.streamCreationFailed)
        continuation = nil
    }
}

private actor StateRecorder {
    private var states: [MonitoringRuntimeState] = []
    func append(_ state: MonitoringRuntimeState) { states.append(state) }
    func values() -> [MonitoringRuntimeState] { states }
}

private actor SignalRecorder {
    private var signals: [FileChangeSignal] = []
    func append(_ signal: FileChangeSignal) { signals.append(signal) }
    func values() -> [FileChangeSignal] { signals }
}

private actor BatchRecorder {
    private var batches: [ChangeBatch] = []
    func append(_ batch: ChangeBatch) { batches.append(batch) }
    func values() -> [ChangeBatch] { batches }
}

func eventually(
    timeoutIterations: Int = 2_000,
    _ condition: @escaping @Sendable () async -> Bool
) async {
    for _ in 0..<timeoutIterations {
        if await condition() { return }
        await Task.yield()
    }
}
