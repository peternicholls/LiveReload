import Foundation

public enum ProjectStoreLoadOutcome: Equatable, Sendable {
    case loaded(ConfigurationEnvelope)
    case empty(ConfigurationEnvelope)
    case recoveredFromCorruption(ConfigurationEnvelope)
    case unsupportedFutureVersion(Int)
}

public enum ProjectStoreError: Error, Equatable, Sendable {
    case notLoaded
    case projectNotFound
    case duplicateFolderIdentity
    case futureSchemaVersion(Int)
    case persistenceFailure
}

public actor ProjectStore {
    public static let configurationFilename = "projects.json"

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var envelope: ConfigurationEnvelope?

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public static func applicationSupportURL(
        fileManager: FileManager = .default,
        bundleIdentifier: String = "com.peternicholls.LiveReload.Modern"
    ) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appending(path: bundleIdentifier, directoryHint: .isDirectory)
            .appending(path: configurationFilename)
    }

    @discardableResult
    public func load() throws -> ProjectStoreLoadOutcome {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            let empty = ConfigurationEnvelope.empty()
            envelope = empty
            return .empty(empty)
        }

        let data = try Data(contentsOf: fileURL)
        do {
            let decoded = try decoder.decode(ConfigurationEnvelope.self, from: data)
            do {
                try decoded.validate()
            } catch ConfigurationError.unsupportedFutureVersion(let version) {
                return .unsupportedFutureVersion(version)
            }
            envelope = decoded
            return .loaded(decoded)
        } catch ConfigurationError.unsupportedFutureVersion(let version) {
            return .unsupportedFutureVersion(version)
        } catch {
            try quarantineCorruptFile()
            let empty = ConfigurationEnvelope.empty()
            envelope = empty
            return .recoveredFromCorruption(empty)
        }
    }

    public func snapshot() throws -> ConfigurationEnvelope {
        guard let envelope else { throw ProjectStoreError.notLoaded }
        return envelope
    }

    @discardableResult
    public func add(_ project: ProjectConfiguration) throws -> ConfigurationEnvelope {
        var current = try snapshot()
        guard !current.projects.contains(where: {
            $0.folderReference.normalizedIdentity == project.folderReference.normalizedIdentity
        }) else { throw ProjectStoreError.duplicateFolderIdentity }
        current.projects.append(try project.validated())
        return try persist(current)
    }

    @discardableResult
    public func update(_ project: ProjectConfiguration) throws -> ConfigurationEnvelope {
        var current = try snapshot()
        guard let index = current.projects.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectStoreError.projectNotFound
        }
        guard !current.projects.enumerated().contains(where: { offset, candidate in
            offset != index && candidate.folderReference.normalizedIdentity == project.folderReference.normalizedIdentity
        }) else { throw ProjectStoreError.duplicateFolderIdentity }
        current.projects[index] = try project.validated()
        return try persist(current)
    }

    @discardableResult
    public func replaceFolderAccess(
        projectID: UUID,
        reference: FolderReference,
        state: FolderAccessState = .available
    ) throws -> ConfigurationEnvelope {
        var current = try snapshot()
        guard let index = current.projects.firstIndex(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        guard !current.projects.enumerated().contains(where: { offset, candidate in
            offset != index && candidate.folderReference.normalizedIdentity == reference.normalizedIdentity
        }) else { throw ProjectStoreError.duplicateFolderIdentity }
        current.projects[index].folderReference = reference
        current.projects[index].folderAccessState = state
        return try persist(current)
    }

    @discardableResult
    public func setAccessState(projectID: UUID, state: FolderAccessState) throws -> ConfigurationEnvelope {
        var current = try snapshot()
        guard let index = current.projects.firstIndex(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        current.projects[index].folderAccessState = state
        return try persist(current)
    }

    @discardableResult
    public func remove(projectID: UUID) throws -> ConfigurationEnvelope {
        var current = try snapshot()
        guard current.projects.contains(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        current.projects.removeAll { $0.id == projectID }
        return try persist(current)
    }

    private func persist(_ candidate: ConfigurationEnvelope) throws -> ConfigurationEnvelope {
        var candidate = candidate
        candidate.updatedAt = Date()
        do {
            try candidate.validate()
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(candidate)
            try data.write(to: fileURL, options: [.atomic])
            envelope = candidate
            return candidate
        } catch let error as ProjectStoreError {
            throw error
        } catch {
            throw ProjectStoreError.persistenceFailure
        }
    }

    private func quarantineCorruptFile() throws {
        let stamp = Int(Date().timeIntervalSince1970)
        let quarantineURL = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupt-\(stamp).json")
        try fileManager.moveItem(at: fileURL, to: quarantineURL)
    }
}
