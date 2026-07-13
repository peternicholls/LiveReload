import Foundation

public actor ProjectAccessCoordinator {
    private let store: ProjectStore
    private let provider: any FolderAccessProvider

    public init(store: ProjectStore, provider: any FolderAccessProvider) {
        self.store = store
        self.provider = provider
    }

    @discardableResult
    public func refreshAccess(for projectID: UUID) async throws -> FolderAccessState {
        let envelope = try await store.snapshot()
        guard let project = envelope.projects.first(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        switch await provider.resolve(project.folderReference) {
        case .available(let resolvedReference):
            let token: ScopedAccessToken
            do {
                token = try await provider.beginAccess(to: resolvedReference)
            } catch {
                let state = Self.accessFailureState(for: error)
                _ = try await store.setAccessState(projectID: projectID, state: state)
                return state
            }
            token.release()
            if project.folderReference != resolvedReference || project.folderAccessState != .available {
                _ = try await store.replaceFolderAccess(
                    projectID: projectID,
                    reference: resolvedReference,
                    state: .available
                )
            }
            return .available
        case .stale, .corrupt:
            return try await persist(.needsRepair, for: projectID)
        case .missing:
            return try await persist(.missing, for: projectID)
        case .denied:
            return try await persist(.denied, for: projectID)
        }
    }

    public func repair(projectID: UUID, replacementURL: URL?) async throws {
        let envelope = try await store.snapshot()
        guard let project = envelope.projects.first(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        let replacement = try await provider.repair(project.folderReference, with: replacementURL)
        _ = try await store.replaceFolderAccess(projectID: projectID, reference: replacement)
    }

    private func persist(_ state: FolderAccessState, for projectID: UUID) async throws -> FolderAccessState {
        _ = try await store.setAccessState(projectID: projectID, state: state)
        return state
    }

    private static func accessFailureState(for error: any Error) -> FolderAccessState {
        switch error {
        case FolderAccessError.corruptBookmark,
             FolderAccessError.selectionRequired,
             FolderAccessError.repairCancelled:
            .needsRepair
        case FolderAccessError.accessDenied:
            .denied
        default:
            .denied
        }
    }
}
