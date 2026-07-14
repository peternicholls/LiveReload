# Build and Reload Pipeline Contract

## Inputs

The project pipeline receives settled change batches, manual reload requests, start/stop/pause/resume commands, and lifecycle/recovery signals.

## Ordering

1. A no-build project sends the existing Phase 2 reload decision immediately.
2. A build-enabled project starts at most one run for a settled batch.
3. Batches received while a run is active merge into one pending batch.
4. A successful run emits one reload decision for its input batch, then starts at most one pending follow-up run.
5. Launch failure, nonzero exit, timeout, cancellation, stop, or recovery emits no reload for that run.

## Invariants

- One identifiable pipeline owner controls monitor, build, and reload ordering.
- No project has overlapping runs or an orphan process after stop/removal/app termination.
- A failed project does not stop unrelated project pipelines.
- Pause and repeated commands are idempotent and visible in the projected state.
