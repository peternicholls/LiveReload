import Foundation

public enum RuntimeModelValidationError: Error, Equatable, Sendable {
    case pathMustBeRelative
    case pathEscapesProject
    case pathTooLong
    case emptyChangeBatch
    case tooManyPaths
    case missingProtocolNegotiation
    case unsupportedProtocolVersion(Int)
    case invalidClientCount
    case invalidStateTransition
}

public enum MonitoringRuntimeState: String, Equatable, Sendable {
    case stopped, starting, watching, stopping, recovering, failed

    public func canTransition(to next: Self) -> Bool {
        switch (self, next) {
        case (.stopped, .starting), (.starting, .watching), (.starting, .failed),
             (.watching, .stopping), (.watching, .recovering),
             (.stopping, .stopped), (.recovering, .stopped), (.failed, .stopped):
            true
        default:
            self == next
        }
    }
}

public enum MonitoringRecoveryReason: String, Equatable, Sendable {
    case rootChanged, eventsDropped, scanRequired, folderUnavailable, sourceFailure
}

public enum FileChangeKind: String, CaseIterable, Equatable, Sendable {
    case created, modified, renamed, deleted
}

public struct FileChangeSignal: Equatable, Sendable {
    public static let maximumRelativePathLength = ProtocolLimits.maximumRelativePathBytes

    public let projectID: UUID
    public let relativePath: String?
    public let kind: FileChangeKind?
    public let recoveryReason: MonitoringRecoveryReason?
    public let sequence: UInt64

    public static func change(
        projectID: UUID,
        relativePath: String,
        kind: FileChangeKind,
        sequence: UInt64
    ) throws -> Self {
        guard !relativePath.hasPrefix("/") else { throw RuntimeModelValidationError.pathMustBeRelative }
        guard !relativePath.split(separator: "/", omittingEmptySubsequences: false).contains("..") else {
            throw RuntimeModelValidationError.pathEscapesProject
        }
        guard relativePath.utf8.count <= maximumRelativePathLength else {
            throw RuntimeModelValidationError.pathTooLong
        }
        let normalized = try RelativeProjectPath(relativePath).value
        return Self(
            projectID: projectID,
            relativePath: normalized,
            kind: kind,
            recoveryReason: nil,
            sequence: sequence
        )
    }

    public static func recovery(
        projectID: UUID,
        reason: MonitoringRecoveryReason,
        sequence: UInt64
    ) -> Self {
        Self(projectID: projectID, relativePath: nil, kind: nil, recoveryReason: reason, sequence: sequence)
    }
}

public enum ChangeClassification: String, Equatable, Sendable {
    case stylesheetOnly, fullPage
}

public struct ChangeBatch: Equatable, Sendable {
    public static let maximumPathCount = 1_024

    public let projectID: UUID
    public let relativePaths: [String]
    public let classification: ChangeClassification
    public let receivedAt: Date

    public init(
        projectID: UUID,
        relativePaths: [String],
        classification: ChangeClassification,
        receivedAt: Date = Date()
    ) throws {
        guard !relativePaths.isEmpty else { throw RuntimeModelValidationError.emptyChangeBatch }
        var seen: Set<String> = []
        var ordered: [String] = []
        for rawPath in relativePaths {
            let path = try RelativeProjectPath(rawPath).value
            if seen.insert(path).inserted { ordered.append(path) }
        }
        guard ordered.count <= Self.maximumPathCount else { throw RuntimeModelValidationError.tooManyPaths }
        self.projectID = projectID
        self.relativePaths = ordered
        self.classification = classification
        self.receivedAt = receivedAt
    }
}

public enum ReloadReason: String, Equatable, Sendable {
    case settledChanges, manual
}

public enum ReloadMode: String, Equatable, Sendable {
    case stylesheet, fullPage
}

public struct ReloadDecision: Equatable, Sendable {
    public let projectID: UUID
    public let reason: ReloadReason
    public let mode: ReloadMode
    public let relativePaths: [String]

    public init(batch: ChangeBatch) {
        projectID = batch.projectID
        reason = .settledChanges
        mode = batch.classification == .stylesheetOnly ? .stylesheet : .fullPage
        relativePaths = batch.relativePaths
    }

    public static func manual(projectID: UUID) -> Self {
        Self(projectID: projectID, reason: .manual, mode: .fullPage, relativePaths: [])
    }

    public init(projectID: UUID, reason: ReloadReason, mode: ReloadMode, relativePaths: [String]) {
        self.projectID = projectID
        self.reason = reason
        self.mode = mode
        self.relativePaths = relativePaths
    }
}

public enum ServerPhase: String, Equatable, Sendable {
    case stopped, starting, listening, portConflict, failed
}

public struct ServerState: Equatable, Sendable {
    public static let maximumClientCount = ProtocolLimits.maximumClients
    public static let stopped = ServerState(uncheckedPhase: .stopped, clientCount: 0)
    public static let starting = ServerState(uncheckedPhase: .starting, clientCount: 0)
    public static let portConflict = ServerState(uncheckedPhase: .portConflict, clientCount: 0)
    public static let failed = ServerState(uncheckedPhase: .failed, clientCount: 0)

    public let phase: ServerPhase
    public let clientCount: Int

    public static func listening(clientCount: Int) throws -> Self {
        guard (0...maximumClientCount).contains(clientCount) else {
            throw RuntimeModelValidationError.invalidClientCount
        }
        return Self(uncheckedPhase: .listening, clientCount: clientCount)
    }

    private init(uncheckedPhase: ServerPhase, clientCount: Int) {
        phase = uncheckedPhase
        self.clientCount = clientCount
    }
}

public struct BrowserSessionID: Hashable, Equatable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public enum BrowserSessionState: String, Equatable, Sendable {
    case connected, negotiating, ready, closing, closed, rejected, failed

    public func canTransition(to next: Self) -> Bool {
        switch (self, next) {
        case (.connected, .negotiating), (.negotiating, .ready), (.negotiating, .rejected),
             (.ready, .closing), (.ready, .failed), (.closing, .closed),
             (.rejected, .closed), (.failed, .closed):
            true
        default:
            self == next
        }
    }
}

public struct BrowserSessionSnapshot: Equatable, Sendable {
    public static let supportedProtocolVersion = 7

    public let id: BrowserSessionID
    public let state: BrowserSessionState
    public let negotiatedProtocolVersion: Int?
    public var isReady: Bool { state == .ready }

    public init(
        id: BrowserSessionID,
        state: BrowserSessionState,
        negotiatedProtocolVersion: Int? = nil
    ) throws {
        if state == .ready, negotiatedProtocolVersion == nil {
            throw RuntimeModelValidationError.missingProtocolNegotiation
        }
        if let negotiatedProtocolVersion,
           negotiatedProtocolVersion != Self.supportedProtocolVersion {
            throw RuntimeModelValidationError.unsupportedProtocolVersion(negotiatedProtocolVersion)
        }
        self.id = id
        self.state = state
        self.negotiatedProtocolVersion = negotiatedProtocolVersion
    }
}
