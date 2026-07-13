import Foundation

public enum ProjectStoreLoadOutcome: Equatable, Sendable {
    case loaded(ConfigurationEnvelope)
    case empty(ConfigurationEnvelope)
    case recoveredFromCorruption(ConfigurationEnvelope)
    case recoveryRequired(ConfigurationEnvelope)
    case unsupportedFutureVersion(Int)
}

public enum ProjectStoreError: Error, Equatable, Sendable {
    case notLoaded
    case projectNotFound
    case duplicateFolderIdentity
    case futureSchemaVersion(Int)
    case sourceNotPreserved
    case persistenceFailure
}

public actor ProjectStore {
    public static let configurationFilename = "projects.json"

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let dataReader: @Sendable (URL) throws -> Data
    private var envelope: ConfigurationEnvelope?
    private var writeProtection: WriteProtection?

    private enum WriteProtection {
        case futureSchemaVersion(Int)
        case sourceNotPreserved
    }

    private struct SchemaHeader: Decodable {
        let schemaVersion: Int
    }

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        dataReader = { try Data(contentsOf: $0) }
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    init(
        fileURL: URL,
        fileManager: FileManager,
        dataReader: @escaping @Sendable (URL) throws -> Data
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.dataReader = dataReader
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
            writeProtection = nil
            return .empty(empty)
        }

        let data: Data
        do {
            data = try dataReader(fileURL)
        } catch {
            return requireSourceRecovery()
        }

        do {
            let header = try decoder.decode(SchemaHeader.self, from: data)
            guard header.schemaVersion <= ConfigurationEnvelope.currentSchemaVersion else {
                envelope = nil
                writeProtection = .futureSchemaVersion(header.schemaVersion)
                return .unsupportedFutureVersion(header.schemaVersion)
            }
            let decoded = try decoder.decode(ConfigurationEnvelope.self, from: data)
            try decoded.validate()
            envelope = decoded
            writeProtection = nil
            return .loaded(decoded)
        } catch {
            do {
                try quarantineCorruptFile()
            } catch {
                return requireSourceRecovery()
            }
            let empty = ConfigurationEnvelope.empty()
            envelope = empty
            writeProtection = nil
            return .recoveredFromCorruption(empty)
        }
    }

    public func snapshot() throws -> ConfigurationEnvelope {
        guard let envelope else {
            if case .futureSchemaVersion(let version) = writeProtection {
                throw ProjectStoreError.futureSchemaVersion(version)
            }
            throw ProjectStoreError.notLoaded
        }
        return envelope
    }

    @discardableResult
    public func add(_ project: ProjectConfiguration) throws -> ConfigurationEnvelope {
        try ensureWritable()
        var current = try snapshot()
        guard !current.projects.contains(where: {
            $0.folderReference.normalizedIdentity == project.folderReference.normalizedIdentity
        }) else { throw ProjectStoreError.duplicateFolderIdentity }
        current.projects.append(try project.validated())
        return try persist(current)
    }

    @discardableResult
    public func update(_ project: ProjectConfiguration) throws -> ConfigurationEnvelope {
        try ensureWritable()
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
    public func rename(projectID: UUID, to displayName: String) throws -> ConfigurationEnvelope {
        try ensureWritable()
        var current = try snapshot()
        guard let index = current.projects.firstIndex(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        try current.projects[index].rename(to: displayName)
        return try persist(current)
    }

    @discardableResult
    public func setEnabled(projectID: UUID, enabled: Bool) throws -> ConfigurationEnvelope {
        try ensureWritable()
        var current = try snapshot()
        guard let index = current.projects.firstIndex(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        current.projects[index].isEnabled = enabled
        return try persist(current)
    }

    @discardableResult
    public func replaceFolderAccess(
        projectID: UUID,
        reference: FolderReference,
        state: FolderAccessState = .available
    ) throws -> ConfigurationEnvelope {
        try ensureWritable()
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
        try ensureWritable()
        var current = try snapshot()
        guard let index = current.projects.firstIndex(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        current.projects[index].folderAccessState = state
        return try persist(current)
    }

    @discardableResult
    public func remove(projectID: UUID) throws -> ConfigurationEnvelope {
        try ensureWritable()
        var current = try snapshot()
        guard current.projects.contains(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        current.projects.removeAll { $0.id == projectID }
        return try persist(current)
    }

    private func persist(_ candidate: ConfigurationEnvelope) throws -> ConfigurationEnvelope {
        try ensureWritable()
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

    private func ensureWritable() throws {
        if let writeProtection {
            switch writeProtection {
            case .futureSchemaVersion(let version):
                throw ProjectStoreError.futureSchemaVersion(version)
            case .sourceNotPreserved:
                throw ProjectStoreError.sourceNotPreserved
            }
        }
    }

    private func quarantineCorruptFile() throws {
        let quarantineURL = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupt-\(UUID().uuidString).json")
        try fileManager.moveItem(at: fileURL, to: quarantineURL)
    }

    private func requireSourceRecovery() -> ProjectStoreLoadOutcome {
        let empty = ConfigurationEnvelope.empty()
        envelope = empty
        writeProtection = .sourceNotPreserved
        return .recoveryRequired(empty)
    }
}
