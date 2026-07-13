import Foundation

public enum ModelValidationError: Error, Equatable, Sendable {
    case emptyDisplayName
    case displayNameTooLong
    case invalidBookmarkData
    case invalidFolderIdentity
    case invalidBuildConfiguration
    case invalidIgnoreRule
    case duplicateFolderIdentity
}

public struct FolderReference: Codable, Equatable, Sendable {
    public static let maximumBookmarkDataLength = 1_048_576
    public static let maximumIdentityLength = 4_096

    public private(set) var bookmarkData: Data
    public private(set) var normalizedIdentity: String
    public private(set) var displayLabel: String

    public init(bookmarkData: Data, normalizedIdentity: String, displayLabel: String) throws {
        let identity = normalizedIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bookmarkData.isEmpty, bookmarkData.count <= Self.maximumBookmarkDataLength else {
            throw ModelValidationError.invalidBookmarkData
        }
        guard !identity.isEmpty, identity.count <= Self.maximumIdentityLength else {
            throw ModelValidationError.invalidFolderIdentity
        }
        self.bookmarkData = bookmarkData
        self.normalizedIdentity = identity
        self.displayLabel = Self.safeLabel(displayLabel)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            bookmarkData: container.decode(Data.self, forKey: .bookmarkData),
            normalizedIdentity: container.decode(String.self, forKey: .normalizedIdentity),
            displayLabel: container.decode(String.self, forKey: .displayLabel)
        )
    }

    func validated() throws -> Self {
        try Self(
            bookmarkData: bookmarkData,
            normalizedIdentity: normalizedIdentity,
            displayLabel: displayLabel
        )
    }

    public static func normalizedIdentity(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
            .precomposedStringWithCanonicalMapping
            .lowercased()
    }

    private static func safeLabel(_ value: String) -> String {
        let label = URL(fileURLWithPath: value).lastPathComponent
        return String((label.isEmpty ? "Selected Folder" : label).prefix(120))
    }
}

public enum FolderAccessState: String, Codable, CaseIterable, Sendable {
    case available
    case needsRepair
    case missing
    case denied
}

public struct BuildConfiguration: Codable, Equatable, Sendable {
    public static let maximumPlaceholderNameLength = 80

    public private(set) var placeholderName: String

    public init(placeholderName: String = "Deferred") {
        self.placeholderName = String(placeholderName.prefix(Self.maximumPlaceholderNameLength))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(String.self, forKey: .placeholderName)
        guard value.count <= Self.maximumPlaceholderNameLength else {
            throw ModelValidationError.invalidBuildConfiguration
        }
        self.init(placeholderName: value)
    }

    func validate() throws {
        guard placeholderName.count <= Self.maximumPlaceholderNameLength else {
            throw ModelValidationError.invalidBuildConfiguration
        }
    }
}

public struct IgnoreRule: Codable, Equatable, Sendable {
    public static let maximumPatternLength = 256

    public private(set) var pattern: String

    public init(pattern: String) throws {
        let value = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= Self.maximumPatternLength else {
            throw ModelValidationError.invalidIgnoreRule
        }
        self.pattern = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(pattern: container.decode(String.self, forKey: .pattern))
    }

    func validate() throws {
        _ = try Self(pattern: pattern)
    }
}

public enum MonitoringState: String, Codable, Sendable {
    case disabled
    case notStarted
}

public struct ProjectConfiguration: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var displayName: String
    public var isEnabled: Bool
    public var folderReference: FolderReference
    public var folderAccessState: FolderAccessState
    public var buildConfiguration: BuildConfiguration
    public var ignoreRules: [IgnoreRule]
    public var monitoringState: MonitoringState

    public init(
        id: UUID = UUID(),
        displayName: String,
        isEnabled: Bool = true,
        folderReference: FolderReference,
        folderAccessState: FolderAccessState = .available,
        buildConfiguration: BuildConfiguration = .init(),
        ignoreRules: [IgnoreRule] = [],
        monitoringState: MonitoringState = .disabled
    ) throws {
        self.id = id
        self.displayName = try Self.validatedDisplayName(displayName)
        self.isEnabled = isEnabled
        self.folderReference = folderReference
        self.folderAccessState = folderAccessState
        self.buildConfiguration = buildConfiguration
        self.ignoreRules = ignoreRules
        self.monitoringState = monitoringState
        _ = try validated()
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            displayName: container.decode(String.self, forKey: .displayName),
            isEnabled: container.decode(Bool.self, forKey: .isEnabled),
            folderReference: container.decode(FolderReference.self, forKey: .folderReference),
            folderAccessState: container.decode(FolderAccessState.self, forKey: .folderAccessState),
            buildConfiguration: container.decode(BuildConfiguration.self, forKey: .buildConfiguration),
            ignoreRules: container.decode([IgnoreRule].self, forKey: .ignoreRules),
            monitoringState: container.decode(MonitoringState.self, forKey: .monitoringState)
        )
    }

    public mutating func rename(to value: String) throws {
        displayName = try Self.validatedDisplayName(value)
    }

    public func validated() throws -> Self {
        var result = self
        result.displayName = try Self.validatedDisplayName(displayName)
        _ = try folderReference.validated()
        try buildConfiguration.validate()
        for rule in ignoreRules {
            try rule.validate()
        }
        return result
    }

    private static func validatedDisplayName(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ModelValidationError.emptyDisplayName }
        guard trimmed.count <= 120 else { throw ModelValidationError.displayNameTooLong }
        return trimmed
    }
}
