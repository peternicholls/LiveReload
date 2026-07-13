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
        let state: FolderAccessState
        switch await provider.resolve(project.folderReference) {
        case .available:
            state = .available
        case .stale, .corrupt:
            state = .needsRepair
        case .missing:
            state = .missing
        case .denied:
            state = .denied
        }
        _ = try await store.setAccessState(projectID: projectID, state: state)
        return state
    }

    public func repair(projectID: UUID, replacementURL: URL?) async throws {
        let envelope = try await store.snapshot()
        guard let project = envelope.projects.first(where: { $0.id == projectID }) else {
            throw ProjectStoreError.projectNotFound
        }
        let replacement = try await provider.repair(project.folderReference, with: replacementURL)
        _ = try await store.replaceFolderAccess(projectID: projectID, reference: replacement)
    }
}
