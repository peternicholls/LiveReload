import Foundation

public enum ModelValidationError: Error, Equatable, Sendable {
    case emptyDisplayName
    case displayNameTooLong
    case invalidFolderIdentity
    case invalidIgnoreRule
    case duplicateFolderIdentity
}

public struct FolderReference: Codable, Equatable, Sendable {
    public var bookmarkData: Data
    public var normalizedIdentity: String
    public var displayLabel: String

    public init(bookmarkData: Data, normalizedIdentity: String, displayLabel: String) throws {
        let identity = normalizedIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identity.isEmpty else { throw ModelValidationError.invalidFolderIdentity }
        self.bookmarkData = bookmarkData
        self.normalizedIdentity = identity
        self.displayLabel = Self.safeLabel(displayLabel)
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
    public var placeholderName: String

    public init(placeholderName: String = "Deferred") {
        self.placeholderName = String(placeholderName.prefix(80))
    }
}

public struct IgnoreRule: Codable, Equatable, Sendable {
    public var pattern: String

    public init(pattern: String) throws {
        let value = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 256 else { throw ModelValidationError.invalidIgnoreRule }
        self.pattern = value
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
    }

    public mutating func rename(to value: String) throws {
        displayName = try Self.validatedDisplayName(value)
    }

    public func validated() throws -> Self {
        _ = try Self.validatedDisplayName(displayName)
        guard !folderReference.normalizedIdentity.isEmpty else {
            throw ModelValidationError.invalidFolderIdentity
        }
        return self
    }

    private static func validatedDisplayName(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ModelValidationError.emptyDisplayName }
        guard trimmed.count <= 120 else { throw ModelValidationError.displayNameTooLong }
        return trimmed
    }
}
