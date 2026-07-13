# Modern LiveReload User Guide

## Status

The modern application is not released. The private Phase 1 build supports local project configuration and recovery only; filesystem monitoring, browser reload, and build execution are not available.

## Supported behavior table

| Capability | Status | Evidence / next owner |
|---|---|---|
| Add, restore, rename, enable, repair, and remove projects | implemented in Phase 1 private build | `scripts/verify-modern.sh` and foundation evidence |
| Filesystem monitoring | deferred | Phase 2 `reload-loop` |
| Browser reload server | deferred | Phase 2 `reload-loop` |
| Build commands | deferred | Phase 3 `developer-workflow` |
| Public distribution | deferred | Phase 4 `private-preview` |

## Project lifecycle

1. Choose **Add Project** or press Command-N, then explicitly select a folder.
2. Select the project to edit its display name or enabled placeholder. Enabled does not start monitoring in Phase 1.
3. Saved folder access is rechecked on every launch. If access becomes stale, missing, or denied, the project remains listed with text and an icon explaining the state. Choose **Repair Access** and select the replacement folder; name, identity, and settings are retained.
4. Choose **Remove Project…** and confirm **Remove Configuration** to remove the saved configuration and bookmark. Source files are never deleted.

While a rename, enabled-state change, repair, or removal is being saved, that project's mutation controls are temporarily disabled and a progress label is shown. Other projects remain independently selectable.

The empty state, project rows, fields, enabled control, repair action, removal confirmation, and activity summaries are keyboard-accessible and have VoiceOver labels/test identifiers. State is expressed with text and symbols, not colour alone; system text styles and semantic colours adapt to text size and light/dark appearance.

Recoverable configuration and access errors say what was preserved and the next safe action. A configuration created by a newer app, or an unreadable configuration that cannot be moved aside safely, remains unchanged and write-protected. Restore storage access and relaunch before changing projects. Activity history is limited to 200 redacted summaries. Do not use the Phase 1 build for filesystem monitoring, browser reload, build commands, public distribution, or App Sandbox workflows.
