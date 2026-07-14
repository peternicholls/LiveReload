# Phase 3 Data Model

## BuildConfiguration

Represents the optional build workflow owned by one project.

- `enabled`: whether settled batches invoke the build
- `executable`: validated file URL
- `arguments`: ordered, non-interpolated argument values
- `workingDirectory`: validated directory URL
- `environmentAdditions`: validated key/value additions; values are never emitted in activity summaries
- `timeout`: bounded duration

Validation requires a readable/executable file, a usable working directory, a positive timeout within the documented maximum, and environment keys matching the supported identifier grammar. Decoding supplies safe defaults for fields added by migration and preserves the prior valid configuration when validation fails.

## BuildRun

One actor-owned child-process lifecycle.

- `id`, `projectID`, `startedAt`, `finishedAt`
- `state`: queued, running, succeeded, failed, cancelled, timedOut, stopped
- `exitCode` when available
- `outputSummary`: bounded, redacted stdout/stderr excerpts and truncation flag
- `failureReason`: launch, nonzero exit, timeout, cancellation, or lifecycle stop

Only the owning `BuildRunner` may transition a run. Terminal state is idempotent.

## BuildBatch

An ordered, de-duplicated collection of project-relative changed paths plus a source (`fileChange` or `manual`). A batch is immutable once handed to a build. Events arriving during a run merge into one pending batch; a pending batch is cleared only when its follow-up run starts or the project stops.

## GlobalSettings

Validated defaults for port, debounce interval, activity-history limit, default exclusions, and launch behavior. Unknown future fields survive migration where the existing persistence envelope permits it; invalid known values fall back to documented defaults and create a recovery activity.

## MenuBarStatus and RecoveryState

`MenuBarStatus` is a derived summary of app health, project states, connected browser count, and available commands. `RecoveryState` identifies affected scope, preserves configuration, stores a redacted explanation, and exposes a direct repair/retry/correction action. Neither entity stores raw environments or unrelated source contents.

## Relationships and invariants

- One project has zero or one `BuildConfiguration` and zero or one active `BuildRun`.
- One project pipeline owns its active run and pending batch.
- Global settings apply to all projects; project values override only explicitly supported fields.
- A successful run permits one reload for its input batch; every unsuccessful terminal state suppresses that reload.
- Stopped or removed projects own no process, monitor, or pending batch.
