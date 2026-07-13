import AppKit
import CoreServices
import Foundation

func log(_ text: String) {
    FileHandle.standardOutput.write(Data((text + "\n").utf8))
}

struct EventRecord: Sendable {
    let path: String
    let flags: FSEventStreamEventFlags

    var recoveryRequired: Bool {
        flags & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0 ||
        flags & FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped) != 0 ||
        flags & FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped) != 0 ||
        flags & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0
    }
}

final class Monitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "livereload.phase0.fsevents")
    private var stream: FSEventStreamRef?
    private let lock = NSLock()
    private(set) var records: [EventRecord] = []

    func start(path: String) throws {
        guard stream == nil else { throw NSError(domain: "FSEventsPrototype", code: 1, userInfo: [NSLocalizedDescriptionKey: "already started"]) }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, pathsPointer, flagsPointer, _ in
            guard let info else { return }
            let monitor = Unmanaged<Monitor>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(pathsPointer, to: NSArray.self) as! [String]
            let copied = (0..<count).map { EventRecord(path: paths[$0], flags: flagsPointer[$0]) }
            monitor.record(copied)
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot)
        guard let created = FSEventStreamCreate(nil, callback, &context, [path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.05, flags) else {
            throw NSError(domain: "FSEventsPrototype", code: 2, userInfo: [NSLocalizedDescriptionKey: "stream creation failed"])
        }
        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created); FSEventStreamRelease(created)
            throw NSError(domain: "FSEventsPrototype", code: 3, userInfo: [NSLocalizedDescriptionKey: "stream start failed"])
        }
        stream = created
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    func record(_ events: [EventRecord]) {
        lock.lock(); defer { lock.unlock() }
        records.append(contentsOf: events)
        if records.count > 20_000 { records.removeFirst(records.count - 20_000) }
        for event in events {
            log("EVENT path=\(event.path) recovery=\(event.recoveryRequired)")
        }
    }

    func simulate(flags: FSEventStreamEventFlags) -> EventRecord {
        let record = EventRecord(path: "/simulated", flags: flags)
        self.record([record])
        return record
    }

    deinit { stop() }
}

func bookmarkData(for url: URL) throws -> Data {
    try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
}

func restoreBookmark(at file: URL) throws -> (url: URL, stale: Bool, accessGranted: Bool) {
    var stale = false
    let data = try Data(contentsOf: file)
    let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
    let accessGranted = url.startAccessingSecurityScopedResource()
    if accessGranted { url.stopAccessingSecurityScopedResource() }
    return (url, stale, accessGranted)
}

func repairBookmark(projectID: String, folder: URL, at file: URL) throws {
    let data = try bookmarkData(for: folder)
    try data.write(to: file, options: .atomic)
    log("BOOKMARK-REPAIRED projectID=\(projectID) folder=\(folder.lastPathComponent)")
}

@MainActor
func selectFolder() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    return panel.runModal() == .OK ? panel.url : nil
}

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    switch arguments.first {
    case "watch":
        guard arguments.count >= 2 else { throw NSError(domain: "FSEventsPrototype", code: 4, userInfo: [NSLocalizedDescriptionKey: "watch requires a path"]) }
        let monitor = Monitor(); try monitor.start(path: arguments[1])
        log("STARTED")
        let duration = arguments.count >= 3 ? TimeInterval(arguments[2]) ?? 3 : 3
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            monitor.stop(); log("STOPPED count=\(monitor.records.count)")
            exit(0)
        }
        dispatchMain()
    case "simulate-recovery":
        let monitor = Monitor()
        let record = monitor.simulate(flags: FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagRootChanged))
        guard record.recoveryRequired else { exit(2) }
        log("RECOVERY-REQUIRED")
    case "create-bookmark":
        guard arguments.count >= 3 else { throw NSError(domain: "FSEventsPrototype", code: 5, userInfo: [NSLocalizedDescriptionKey: "create-bookmark requires folder and output file"]) }
        let data = try bookmarkData(for: URL(fileURLWithPath: arguments[1], isDirectory: true))
        try data.write(to: URL(fileURLWithPath: arguments[2]), options: .atomic)
        log("BOOKMARK-CREATED")
    case "select-bookmark":
        guard arguments.count >= 2, let folder = MainActor.assumeIsolated({ selectFolder() }) else { throw NSError(domain: "FSEventsPrototype", code: 6, userInfo: [NSLocalizedDescriptionKey: "folder selection cancelled or output missing"]) }
        try bookmarkData(for: folder).write(to: URL(fileURLWithPath: arguments[1]), options: .atomic)
        log("BOOKMARK-CREATED")
    case "restore-bookmark":
        guard arguments.count >= 2 else { throw NSError(domain: "FSEventsPrototype", code: 7, userInfo: [NSLocalizedDescriptionKey: "restore-bookmark requires file"]) }
        let restored = try restoreBookmark(at: URL(fileURLWithPath: arguments[1]))
        log("BOOKMARK-RESTORED stale=\(restored.stale) access=\(restored.accessGranted) path=\(restored.url.lastPathComponent)")
    case "repair-bookmark":
        guard arguments.count >= 4 else { throw NSError(domain: "FSEventsPrototype", code: 8, userInfo: [NSLocalizedDescriptionKey: "repair-bookmark requires project ID, replacement folder, and output file"]) }
        try repairBookmark(projectID: arguments[1], folder: URL(fileURLWithPath: arguments[2], isDirectory: true), at: URL(fileURLWithPath: arguments[3]))
    default:
        log("usage: watch PATH | simulate-recovery | create-bookmark FOLDER FILE | restore-bookmark FILE | repair-bookmark PROJECT-ID FOLDER FILE | select-bookmark FILE")
    }
} catch {
    fputs("FAILED \(error.localizedDescription)\n", stderr)
    exit(2)
}
