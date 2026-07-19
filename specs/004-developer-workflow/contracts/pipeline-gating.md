# Build and Reload Pipeline Contract

## Inputs

The project pipeline receives settled change batches, **Reload Now** requests, **Cancel Current Build** requests, start/stop/pause/resume commands, and lifecycle/recovery signals. **Reload Now** is an explicit immediate manual broadcast that bypasses build gating and does not consume, cancel, or reorder active or pending build batches.

## Ordering

1. A no-build project sends the existing Phase 2 reload decision immediately.
2. A build-enabled project starts at most one run for a settled batch.
3. Batches received while a run is active merge into one pending batch.
4. A successful run emits one reload decision for its input batch, then starts exactly one pending follow-up when one exists and the project remains enabled and watching.
5. Launch failure, nonzero exit, timeout, or run-only cancellation emits no reload for that run, then starts exactly one pending follow-up when one exists and the project remains enabled and watching.
6. Pause, stop, folder-access loss, project removal, or app termination cancels the active run, emits no reload, discards the pending batch, and starts no follow-up.
7. **Reload Now** emits one immediate manual reload decision while watching, even when a build is configured, without changing build state.
8. **Cancel Current Build** is accepted only while running; it produces a run-only cancellation and starts one pending follow-up when one exists and the project remains enabled and watching.

## Invariants

- One identifiable pipeline owner controls monitor, build, and reload ordering.
- No project has overlapping runs or an orphan process-group member after stop/removal/app termination.
- A failed project does not stop unrelated project pipelines.
- Pause and repeated commands are idempotent and visible in the projected state.
- Sleep/wake and network/path reconciliation do not duplicate a listener, monitor, process group, or pending build.
