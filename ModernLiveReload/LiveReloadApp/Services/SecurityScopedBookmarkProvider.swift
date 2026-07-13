import Foundation
import LiveReloadCore

actor SecurityScopedBookmarkProvider: FolderAccessProvider {
    func createReference(for selectedURL: URL) throws -> FolderReference {
        let data = try selectedURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return try FolderReference(
            bookmarkData: data,
            normalizedIdentity: FolderReference.normalizedIdentity(for: selectedURL),
            displayLabel: selectedURL.lastPathComponent
        )
    }

    func resolve(_ reference: FolderReference) -> FolderAccessOutcome {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: reference.bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
            if isStale { return .stale(reference: reference) }
            return .available(reference: reference)
        } catch CocoaError.fileReadNoPermission {
            return .denied
        } catch {
            return .corrupt
        }
    }

    func beginAccess(to reference: FolderReference) throws -> ScopedAccessToken {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: reference.bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        guard !isStale else { throw FolderAccessError.corruptBookmark }
        guard url.startAccessingSecurityScopedResource() else { throw FolderAccessError.accessDenied }
        return ScopedAccessToken { url.stopAccessingSecurityScopedResource() }
    }

    func repair(_ reference: FolderReference, with selectedURL: URL?) throws -> FolderReference {
        guard let selectedURL else { throw FolderAccessError.repairCancelled }
        return try createReference(for: selectedURL)
    }
}
