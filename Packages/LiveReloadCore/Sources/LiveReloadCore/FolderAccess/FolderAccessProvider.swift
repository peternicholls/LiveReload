import Foundation

public enum FolderAccessOutcome: Equatable, Sendable {
    case available(reference: FolderReference)
    case stale(reference: FolderReference)
    case missing
    case denied
    case corrupt
}

public enum FolderAccessError: Error, Equatable, Sendable {
    case selectionRequired
    case accessDenied
    case corruptBookmark
    case repairCancelled
}

public final class ScopedAccessToken: @unchecked Sendable {
    private let lock = NSLock()
    private var releaseAction: (@Sendable () -> Void)?

    public init(release: @escaping @Sendable () -> Void) {
        releaseAction = release
    }

    public func release() {
        lock.lock()
        let action = releaseAction
        releaseAction = nil
        lock.unlock()
        action?()
    }

    deinit {
        release()
    }
}

public protocol FolderAccessProvider: Sendable {
    func createReference(for selectedURL: URL) async throws -> FolderReference
    func resolve(_ reference: FolderReference) async -> FolderAccessOutcome
    func beginAccess(to reference: FolderReference) async throws -> ScopedAccessToken
    func repair(_ reference: FolderReference, with selectedURL: URL?) async throws -> FolderReference
}
