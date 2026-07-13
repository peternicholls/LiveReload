import Foundation

public enum ActivityCategory: String, Codable, CaseIterable, Sendable {
    case app, storage, folderAccess, monitoring, network, build, pipeline
}

public enum ActivitySeverity: String, Codable, CaseIterable, Sendable {
    case debug, info, warning, error
}

public enum ActivityRedactor {
    public static let maximumSummaryLength = 512

    public static func redact(_ rawValue: String) -> String {
        var value = rawValue.replacingOccurrences(
            of: #"(?i)(password|token|secret|api[_-]?key)\s*[:=]\s*[^\s,;]+"#,
            with: "$1=[REDACTED]",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?<![A-Za-z0-9])/(?:Users|home|Volumes|private|var|tmp)/[^\s,;]+"#,
            with: "[REDACTED_PATH]",
            options: .regularExpression
        )
        if value.count > maximumSummaryLength {
            value = String(value.prefix(maximumSummaryLength - 1)) + "…"
        }
        return value
    }
}

public struct ActivityEvent: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let category: ActivityCategory
    public let severity: ActivitySeverity
    public let summary: String
    public let projectID: UUID?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: ActivityCategory,
        severity: ActivitySeverity,
        summary: String,
        projectID: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.severity = severity
        self.summary = ActivityRedactor.redact(summary)
        self.projectID = projectID
    }
}
