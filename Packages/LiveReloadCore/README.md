# LiveReloadCore

`LiveReloadCore` is the UI-free, dependency-free domain boundary for the modern app. Source and tests must not import SwiftUI or AppKit.

## Persisted invariants

- `ConfigurationEnvelope.schemaVersion` is positive and must not exceed the current version. Future versions are preserved and rejected rather than downgraded.
- Project IDs are stable across rename and folder-access repair.
- Display names are trimmed, non-empty, and at most 120 characters.
- Folder identity is provider-normalized and unique across projects. Display names and raw URLs are never used for duplicate detection.
- Removal deletes configuration and bookmark bytes only; it never deletes the selected folder.
- `BuildConfiguration`, `IgnoreRule`, and `MonitoringState` are non-executable placeholders. Monitoring, reload networking, and build execution remain deferred.

## Ownership

`ProjectStore` and `ActivityStore` are actors. The store is the sole production configuration writer and uses atomic file replacement. `FolderAccessProvider` isolates platform bookmark APIs; deterministic tests use `FakeFolderAccessProvider`. `ProjectAccessCoordinator` persists access outcomes without discarding project configuration.

`folderAccessState` is persisted recovery state. Scoped access tokens are runtime-only and balance release exactly once. Activity summaries are redacted and bounded before entering the actor-owned 200-event history.

## Verification

Run `swift test --package-path Packages/LiveReloadCore` from the repository root. The package compiles with Swift 6 and warnings as errors.
