import Foundation

public enum ActivityCategory: String, Codable, CaseIterable, Sendable {
    case app, storage, folderAccess, monitoring, network, build, pipeline
}

public enum ActivitySeverity: String, Codable, CaseIterable, Sendable {
    case debug, info, warning, error
}

public enum ActivityRedactor {
    public static let maximumSummaryLength = 512

    private static let secretPattern =
        #"(?i)(password|token|secret|api[_-]?key)\s*[:=]\s*[^\s,;]+"#
    private static let absolutePathPattern =
        #"(?i)(?:file://(?:localhost)?|(?<![A-Za-z0-9:/]))/(?!/)(?:(?![\r\n,;\"'<>]|\s+(?:password|token|secret|api[_-]?key)\s*[:=]).)*"#

    public static func redact(_ rawValue: String) -> String {
        var value = rawValue.replacingOccurrences(
            of: secretPattern,
            with: "$1=[REDACTED]",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: absolutePathPattern,
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

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let category = try container.decode(ActivityCategory.self, forKey: .category)
        let severity = try container.decode(ActivitySeverity.self, forKey: .severity)
        let summary = try container.decode(String.self, forKey: .summary)
        let projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        self.init(
            id: id,
            timestamp: timestamp,
            category: category,
            severity: severity,
            summary: summary,
            projectID: projectID
        )
    }
}
