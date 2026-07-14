# Phase 3 Research Decisions

## Decision: Use direct executable-plus-arguments process execution

**Rationale**: The constitution explicitly prohibits shell interpolation for build commands. Foundation's process primitives accept an executable URL and argument array, which preserves argument boundaries and makes launch failures testable.

**Alternatives considered**: `/bin/sh -c` was rejected because configuration could become code execution and quoting would be ambiguous. Compiler presets were deferred because the roadmap requires user-supplied general commands first.

## Decision: Keep build orchestration inside the existing project pipeline

**Rationale**: `ProjectPipeline` already serializes monitor batches, manual reloads, recovery, and browser broadcasts. Extending that actor keeps one identifiable owner for build/reload ordering and avoids a second scheduler that could overlap work.

**Alternatives considered**: A global build queue was rejected because projects must remain independently recoverable and a queue would add cross-project coupling without a stated requirement.

## Decision: Bound output at the process boundary and retain summaries, not raw environments

**Rationale**: Process output and environment additions are untrusted and may contain secrets or unbounded compiler logs. Incremental bounded capture supports actionable failure UI without turning activity history into a source or credential store.

**Alternatives considered**: Persisting complete stdout/stderr was rejected for privacy, storage growth, and redaction risk. Dropping all output was rejected because nonzero exits and launch errors need actionable context.

## Decision: Treat timeout and cancellation as first-class results

**Rationale**: A long-running build must be distinguishable from a compiler failure, and project/app teardown must prove child-process ownership. Graceful termination followed by a forced kill gives fixture tests deterministic cleanup.

**Alternatives considered**: A single generic failure result was rejected because recovery actions differ. Waiting indefinitely for termination was rejected because it violates lifecycle guarantees.

## Decision: Use shared command routing for menu bar and window controls

**Rationale**: The same pause/resume/reload/recovery action must have one mutation gate regardless of presentation surface. This reduces race opportunities and lets UI tests validate behavior through either route.

**Alternatives considered**: Duplicated menu-specific mutations were rejected because they would drift from the main-window path and make rapid-click behavior harder to reason about.

## Decision: Defer launch-at-login implementation

**Rationale**: The roadmap marks launch at login as a stretch story and it does not unblock build-before-reload or daily menu-bar controls. Research can be recorded later without expanding this feature's acceptance surface.

**Alternatives considered**: Including it now was rejected to keep Phase 3's sprint gate focused on build/process lifecycle and recovery.
