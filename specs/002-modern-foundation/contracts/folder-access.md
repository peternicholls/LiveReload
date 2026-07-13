# Folder Access Contract

## Responsibilities

`FolderAccessProvider` isolates macOS bookmark APIs from models, persistence, and UI. Its real adapter may use security-scoped bookmark APIs; tests use a deterministic fake.

## Required behavior

- Create a bookmark only from an explicitly user-selected folder.
- Resolve a persisted bookmark to one of: available, stale/repair-required, missing, denied, or corrupt/repair-required.
- Return a scoped-access token only for available access. The token has one owner and balances begin/end access exactly once, including cancellation/error paths.
- Report a normalized folder identity for duplicate detection without requiring the UI to compare raw paths.
- Repair accepts a replacement selection and returns replacement access data; `ProjectStore` retains the caller’s project identity/settings while persisting it.
- Never silently broaden access, retry a denied selection without user action, or discard a project because access failed.

## Test obligations

The fake provider covers available, stale, missing, denied, corrupt, duplicate identity, begin/end balance, repair success, and repair cancellation. One integration scenario exercises the real adapter with a user-selected temporary folder where platform permissions permit it.
