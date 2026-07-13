# Project Store Contract

## Responsibilities

`ProjectStore` is the only production boundary that reads or writes the configuration envelope. It provides typed operations: load, add, update, replace folder access, remove, and snapshot.

## Required behavior

- Every mutation validates model invariants before write.
- Writes use an atomic replace in Application Support; no caller writes configuration files directly.
- A missing file yields an empty configuration without an error event.
- A corrupt or unreadable file is preserved under a diagnostic filename, the active state becomes a safe empty configuration, and a redacted warning is emitted.
- An unsupported future schema is preserved and reported; it is never downgraded or overwritten.
- Duplicate detection compares provider-normalized folder identity, not display names or raw URLs.
- Removal removes only the configuration entry and associated bookmark bytes; it never deletes the selected folder.

## Result surface

Operations return typed success/failure values suitable for both UI and tests. Failures distinguish validation, duplicate, persistence, future-schema, and recoverable-corruption cases without embedding absolute paths in user-visible text.

## Test obligations

Temporary-directory integration tests cover empty load, round trip, interrupted/failed replacement handling, corrupt preservation, future-version rejection, duplicate identity, update, repair replacement, and configuration-only removal.
