# Phase 3 Data Model

## BuildConfiguration

Represents the optional build workflow owned by one project.

- `enabled`: whether settled batches invoke the build
- `executable`: validated file URL
- `arguments`: ordered, non-interpolated argument values
- `workingDirectory`: validated directory URL
- `environmentAdditions`: validated key/value additions; values are never emitted in activity summaries
- `timeout`: bounded duration

Validation requires a standardized executable URL of at most 4,096 UTF-8 bytes that identifies a regular executable file, and a standardized/symlink-resolved working directory of at most 4,096 UTF-8 bytes inside the accessible selected project root. Access is revalidated immediately before launch; a regular executable replaced in place is allowed. Timeout defaults to 300 seconds within `1...3600`. Arguments are limited to 256 entries, 4,096 UTF-8 bytes each, and 65,536 bytes total. Environment additions are limited to 64 entries, 128-byte identifier keys, 8,192-byte values, and 65,536 bytes total; exact keys `PWD`, `OLDPWD`, `SHLVL`, and `_` plus prefixes `DYLD_` and `LD_` are rejected, while `PATH` is allowed. NUL is rejected in paths, arguments, keys, and values. Decoding supplies safe defaults for known fields added by migration and preserves the prior valid configuration when validation fails.

## BuildRun

One actor-owned process-group lifecycle.

- `id`, `projectID`, `startedAt`, `finishedAt`
- `state`: queued, running, succeeded, failed, cancelled, timedOut, stopped
- `exitCode` when available
- `outputSummary`: redacted stdout/stderr excerpts with a 4,096-byte terminal cap and truncation flag; active combined capture is capped at 1,048,576 bytes and displayed lines at 16,384 bytes
- `failureReason`: launch, nonzero exit, timeout, cancellation, or lifecycle stop

Only the owning `BuildRunner` may transition a run. It owns the launched process group through a narrow process-control adapter so the direct process and fixture-supported descendants share teardown. Graceful termination has a 2-second maximum before forced termination. Terminal state is idempotent.

## BuildBatch

An ordered, de-duplicated collection of project-relative changed paths with source `fileChange`. A batch is immutable once handed to a build. Events arriving during a run merge into one pending batch. Success, launch failure, nonzero exit, timeout, or run-only cancellation starts the pending batch once when the project remains enabled and watching. Pause, stop, access loss, removal, or app termination discards it. **Reload Now** is a separate immediate command, not a `BuildBatch`, and does not mutate active or pending work.

## GlobalSettings

Validated defaults are loopback port `35729` in `1024...65535`, debounce `250 ms` in `100...500 ms`, activity history `200` in `50...500`, an empty custom global-exclusion list, and launch behavior `showMainWindow` or `menuBarOnly`. Fixed built-ins remain in `ExclusionPolicy`; custom global patterns apply next and per-project patterns last, with any match excluding and preview reporting the matching layer. Launch behavior affects presentation after user-initiated launch only. Known older fields receive explicit migration defaults; unsupported future schema versions remain write-protected. Arbitrary unknown keys inside a supported schema are not guaranteed to survive typed decode/re-encode. Invalid known values preserve the last valid settings and create a recovery activity.

## MenuBarStatus and RecoveryState

`MenuBarStatus` is a derived summary of app health, project states, connected browser count, and available commands. `RecoveryState` identifies affected scope, preserves configuration, stores a redacted explanation, and exposes a direct repair/retry/correction action. Neither entity stores raw environments, argument values, or unrelated source contents. Build-configuration summaries expose only the executable label, project-relative working directory, argument count, environment-key names, timeout, and enabled state. Captured output redacts exact nonempty configured environment values before bounding.

## Relationships and invariants

- One project has zero or one `BuildConfiguration` and zero or one active `BuildRun`.
- One project pipeline owns its active run and pending batch.
- Global settings apply to all projects; project values override only explicitly supported fields.
- A successful run permits one reload for its input batch; every unsuccessful terminal state suppresses that reload.
- **Reload Now** permits one immediate manual broadcast without consuming, cancelling, or reordering active or pending build work.
- Stopped, inaccessible, or removed projects own no process group, monitor, or pending batch.
- Live output plus retained terminal summaries stay within a 5 MiB logical diagnostic-payload budget for two maximum-output active runs and 500 maximum-size summaries.
