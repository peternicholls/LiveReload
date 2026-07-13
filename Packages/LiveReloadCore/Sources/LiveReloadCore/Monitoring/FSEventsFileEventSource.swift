import CoreServices
import Foundation

public enum FSEventsSourceError: Error, Equatable, Sendable {
    case invalidRoot
    case streamCreationFailed
    case streamStartFailed
}

public struct FSEventsFileEventSource: FileEventSource {
    private let latency: CFTimeInterval

    public init(latency: CFTimeInterval = 0.1) {
        self.latency = min(max(latency, 0.01), 1.0)
    }

    public func makeStream(projectID: UUID, rootURL: URL) async throws -> any FileEventStream {
        try FSEventsFileEventStream(projectID: projectID, rootURL: rootURL, latency: latency)
    }
}

public final class FSEventsFileEventStream: @unchecked Sendable, FileEventStream {
    private let projectID: UUID
    private let rootURL: URL
    private let queue = DispatchQueue(label: "com.livereload.monitor.fsevents")
    private let lock = NSLock()
    private let signalStream: AsyncStream<FileChangeSignal>
    private let continuation: AsyncStream<FileChangeSignal>.Continuation
    private var nativeStream: FSEventStreamRef?
    private var stopped = false

    init(projectID: UUID, rootURL: URL, latency: CFTimeInterval) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FSEventsSourceError.invalidRoot
        }
        self.projectID = projectID
        self.rootURL = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let pair = AsyncStream<FileChangeSignal>.makeStream(bufferingPolicy: .bufferingNewest(20_000))
        signalStream = pair.stream
        continuation = pair.continuation

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, rawPaths, flags, eventIDs in
            guard let info else { return }
            let owner = Unmanaged<FSEventsFileEventStream>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(rawPaths, to: NSArray.self) as? [String] ?? []
            owner.receive(paths: paths, flags: flags, eventIDs: eventIDs, count: count)
        }
        let createFlags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagWatchRoot
        )
        guard let created = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [self.rootURL.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            createFlags
        ) else {
            throw FSEventsSourceError.streamCreationFailed
        }
        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            throw FSEventsSourceError.streamStartFailed
        }
        nativeStream = created
    }

    public func signals() async -> AsyncStream<FileChangeSignal> { signalStream }

    public func stop() async { stopSynchronously() }

    private func receive(
        paths: [String],
        flags: UnsafePointer<FSEventStreamEventFlags>,
        eventIDs: UnsafePointer<FSEventStreamEventId>,
        count: Int
    ) {
        guard !lock.withLock({ stopped }) else { return }
        for index in 0..<min(count, paths.count) {
            let eventFlags = flags[index]
            let sequence = UInt64(eventIDs[index])
            if let recovery = Self.recoveryReason(for: eventFlags) {
                continuation.yield(.recovery(projectID: projectID, reason: recovery, sequence: sequence))
                continue
            }
            guard let relativePath = try? RelativeProjectPath(
                candidateURL: URL(fileURLWithPath: paths[index]),
                rootURL: rootURL
            ).value else { continue }
            for kind in Self.changeKinds(for: eventFlags) {
                guard let signal = try? FileChangeSignal.change(
                    projectID: projectID,
                    relativePath: relativePath,
                    kind: kind,
                    sequence: sequence
                ) else { continue }
                continuation.yield(signal)
            }
        }
    }

    private static func recoveryReason(for flags: FSEventStreamEventFlags) -> MonitoringRecoveryReason? {
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0 { return .rootChanged }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0 { return .scanRequired }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped) != 0 ||
            flags & FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped) != 0 { return .eventsDropped }
        return nil
    }

    private static func changeKinds(for flags: FSEventStreamEventFlags) -> [FileChangeKind] {
        var kinds: [FileChangeKind] = []
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 { kinds.append(.created) }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0 { kinds.append(.modified) }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0 { kinds.append(.renamed) }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 { kinds.append(.deleted) }
        return kinds.isEmpty ? [.modified] : kinds
    }

    private func stopSynchronously() {
        let stream: FSEventStreamRef? = lock.withLock {
            guard !stopped else { return nil }
            stopped = true
            defer { nativeStream = nil }
            return nativeStream
        }
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        continuation.finish()
    }

    deinit { stopSynchronously() }
}
