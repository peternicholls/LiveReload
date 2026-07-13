import Foundation

public actor FakeFolderAccessProvider: FolderAccessProvider {
    public enum Mode: Sendable {
        case available, stale, missing, denied, corrupt
    }

    private var mode: Mode
    private var beginCount = 0
    private var endCount = 0

    public init(mode: Mode = .available) {
        self.mode = mode
    }

    public func setMode(_ mode: Mode) {
        self.mode = mode
    }

    public func counts() -> (began: Int, ended: Int) {
        (beginCount, endCount)
    }

    public func createReference(for selectedURL: URL) throws -> FolderReference {
        try FolderReference(
            bookmarkData: Data(selectedURL.path.utf8),
            normalizedIdentity: FolderReference.normalizedIdentity(for: selectedURL),
            displayLabel: selectedURL.lastPathComponent
        )
    }

    public func resolve(_ reference: FolderReference) -> FolderAccessOutcome {
        switch mode {
        case .available: .available(reference: reference)
        case .stale: .stale(reference: reference)
        case .missing: .missing
        case .denied: .denied
        case .corrupt: .corrupt
        }
    }

    public func beginAccess(to reference: FolderReference) throws -> ScopedAccessToken {
        guard case .available = mode else { throw FolderAccessError.accessDenied }
        beginCount += 1
        return ScopedAccessToken { [weak self] in
            guard let self else { return }
            Task { await self.recordEnd() }
        }
    }

    public func repair(_ reference: FolderReference, with selectedURL: URL?) throws -> FolderReference {
        guard let selectedURL else { throw FolderAccessError.repairCancelled }
        mode = .available
        return try createReference(for: selectedURL)
    }

    private func recordEnd() {
        endCount += 1
    }
}
