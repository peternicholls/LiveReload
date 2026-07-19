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

**Rationale**: A long-running build must be distinguishable from a compiler failure, and project/app teardown must prove child-process ownership. Apple documents `Process.terminate()` as sending `SIGTERM` to the receiver and its subtasks; a narrow process-control adapter provides the forced escalation needed when graceful termination is ignored. Descendant-spawning fixture tests, not API wording alone, prove cleanup. Source: [Apple `Process.terminate()` documentation](https://developer.apple.com/documentation/foundation/process/terminate%28%29).

**Alternatives considered**: A single generic failure result was rejected because recovery actions differ. Waiting indefinitely for termination was rejected because it violates lifecycle guarantees.

## Decision: Use shared command routing for menu bar and window controls

**Rationale**: The same pause/resume/reload/recovery action must have one mutation gate regardless of presentation surface. This reduces race opportunities and lets UI tests validate behavior through either route.

**Alternatives considered**: Duplicated menu-specific mutations were rejected because they would drift from the main-window path and make rapid-click behavior harder to reason about.

## Decision: Defer launch-at-login implementation

**Rationale**: The roadmap marks launch at login as a stretch story and it does not unblock build-before-reload or daily menu-bar controls. Research can be recorded later without expanding this feature's acceptance surface.

**Alternatives considered**: Including it now was rejected to keep Phase 3's sprint gate focused on build/process lifecycle and recovery.

## Decision: Keep launch behavior separate from launch-at-login

**Rationale**: Phase 3 launch behavior has exactly two values: `showMainWindow` (default) and `menuBarOnly`. They affect presentation after a user starts the app; they do not register a login item, start the server, or restore project monitoring. The roadmap's `SMAppService` registration remains a separate stretch story.

**Alternatives considered**: Treating every launch-related setting as launch-at-login was rejected because it would contradict the explicit deferral and make acceptance criteria unverifiable in this sprint.

## Decision: Preserve manual reload as an explicit build-gate bypass

**Rationale**: Phase 2 already exposes an immediate manual broadcast. Renaming the command **Reload Now** and labelling the bypass preserves that observable behavior while distinguishing it from settled file changes, which remain build-gated. The command does not consume, cancel, or reorder an active or pending build batch.

**Alternatives considered**: Routing manual reload through the configured build was rejected because it would silently change the existing command and make recovery from a known bad build less useful. Cancelling an active build was rejected because it would make presentation context mutate process lifecycle unexpectedly.

## Decision: Process every pending batch unless project lifecycle stops

**Rationale**: Changes that arrive during an unsuccessful run may fix that failure and must not be lost. Success, launch failure, nonzero exit, timeout, and run-only cancellation therefore start one accumulated follow-up when the project remains enabled and watching. Pause, stop, folder-access loss, removal, and app termination are lifecycle boundaries that cancel the run and discard pending work.

**Alternatives considered**: Starting follow-up work only after success was rejected because it strands fixes that arrive during a failed build. Restarting after lifecycle cancellation was rejected because it would violate explicit stop and ownership semantics.

## Decision: Use explicit diagnostic and configuration bounds

**Rationale**: Testable privacy and memory claims require constants, not the word “bounded.” The specification fixes live output at 1 MiB per run, displayed lines at 16 KiB, terminal summaries at 4 KiB, activity history at 50–500 events, timeout at 1–3,600 seconds, and argument/environment/path limits. Two active maximum-output runs plus 500 maximum summaries remain within a 5 MiB logical payload budget.

**Alternatives considered**: Making every limit user-configurable was rejected because it weakens predictable resource use. Using process RSS as the only diagnostic budget was rejected because allocator and framework overhead makes it unsuitable for deterministic contract tests.

## Decision: Reuse project access and revalidate executable URLs

**Rationale**: Phase 3 is not sandboxed. The working directory must resolve inside the selected project root and reuses its existing scoped folder access. The executable is stored as a standardized file URL without a new bookmark and is revalidated as a regular executable file immediately before each launch. This allows a legitimate tool upgrade at the same URL while reporting a missing or non-executable replacement as launch failure.

**Alternatives considered**: Allowing arbitrary working directories was rejected because it expands folder access beyond the selected project without a user story. Adding executable bookmarks now was rejected because App Sandbox remains deferred and the extra persistence boundary has no current platform requirement.

## Decision: Do not promise opaque unknown-key preservation

**Rationale**: The existing typed `Codable` envelope rejects unsupported future schema versions before writing but does not retain arbitrary unknown keys in a supported schema. Phase 3 will migrate known older fields explicitly and keep future-schema write protection; it will not claim lossless round-trip of unknown current-schema keys.

**Alternatives considered**: Adding a parallel raw-JSON preservation layer was rejected because no compatibility requirement justifies that complexity.

## Decision: Layer exclusions and minimize configuration metadata

**Rationale**: Existing fixed exclusions remain the safety baseline. An empty custom global list applies next and per-project patterns apply last; any match excludes, while preview reports the matching layer so precedence is observable. Build summaries expose labels, counts, environment-key names, timeout, and state—not argument or environment values. Exact nonempty configured environment values are redacted from captured output before it is bounded or shown.

**Alternatives considered**: Letting per-project rules re-include fixed exclusions was rejected because the current policy has exclusion-only semantics. Displaying full arguments was rejected because command arguments commonly contain credentials or private paths that cannot be classified reliably.
