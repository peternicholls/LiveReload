import Foundation

public enum ConfigurationError: Error, Equatable, Sendable {
    case invalidSchemaVersion(Int)
    case unsupportedFutureVersion(Int)
    case duplicateFolderIdentity
}

public protocol ConfigurationMigrating: Sendable {
    func migrate(_ data: Data, from sourceVersion: Int, to targetVersion: Int) throws -> Data
}

public struct RejectingConfigurationMigrator: ConfigurationMigrating {
    public init() {}

    public func migrate(_ data: Data, from sourceVersion: Int, to targetVersion: Int) throws -> Data {
        guard sourceVersion == targetVersion else {
            throw ConfigurationError.invalidSchemaVersion(sourceVersion)
        }
        return data
    }
}

public struct ConfigurationEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var projects: [ProjectConfiguration]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        projects: [ProjectConfiguration] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        self.schemaVersion = schemaVersion
        self.projects = projects
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        try validate()
    }

    public static func empty(now: Date = Date()) -> Self {
        // These values are compile-time valid and cannot fail validation.
        try! Self(projects: [], createdAt: now, updatedAt: now)
    }

    public func validate() throws {
        guard schemaVersion > 0 else { throw ConfigurationError.invalidSchemaVersion(schemaVersion) }
        guard schemaVersion <= Self.currentSchemaVersion else {
            throw ConfigurationError.unsupportedFutureVersion(schemaVersion)
        }
        var identities = Set<String>()
        for project in projects {
            _ = try project.validated()
            guard identities.insert(project.folderReference.normalizedIdentity).inserted else {
                throw ConfigurationError.duplicateFolderIdentity
            }
        }
    }
}
