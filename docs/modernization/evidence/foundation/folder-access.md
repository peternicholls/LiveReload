# Folder Access Evidence

## Automated contract coverage

`FolderAccessTests` exercises available, stale, missing, denied, corrupt, balanced scoped access, repair success, repair cancellation, and preservation of project identity/configuration after an access failure. `ProjectStoreTests` verifies folder-preserving configuration removal.

Command: `swift test --package-path Packages/LiveReloadCore`

## Workspace-backed adapter procedure

Use only a disposable empty folder created for this check. In the modern app, select it through the folder picker, quit and relaunch, resolve the stored bookmark, then replace the selection through Repair Access. Confirm the project ID/name/enabled state remain unchanged and remove the project configuration. Confirm the disposable folder remains on disk.

`scripts/verify-bookmark.sh` creates a disposable workspace folder, creates and resolves a real security-scoped bookmark with the same Foundation options as the production adapter, verifies normalized identity and non-stale state, starts scoped access, balances the stop call, and removes the fixture. On 2026-07-13 it passed all checks.

No bookmark bytes or absolute local path are printed or retained in this evidence. Interactive app repair remains part of the final XCUITest/clean-account matrix, but the real bookmark boundary itself is verified.
