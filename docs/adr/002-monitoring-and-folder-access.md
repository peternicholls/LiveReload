# ADR-002: Use direct FSEvents with security-scoped bookmark repair

- Status: accepted
- Date: 2026-07-12
- Deciders: Phase 0 maintainer
- Related tasks/issues: T032–T038, LRN-002
- Supersedes: none

## Context

The app must watch recursively selected project folders, handle coalesced or lost events, restore access across relaunch, and explain inaccessible or moved folders without silently deleting user configuration.

## Decision drivers

- Efficient recursive monitoring on macOS.
- Explicit dropped/root-change recovery.
- Strict-concurrency-safe callback ownership.
- Least-privilege persisted folder access and repairable stale bookmarks.

## Considered options

1. **Direct FSEvents adapter.** Selected: the prototype observed workspace file events, root-change recovery flags, bounded burst behavior, and clean start/stop.
2. **Polling.** Rejected as the primary mechanism due to latency and idle-resource cost; it may remain a diagnostic fallback only if a later specification justifies it.
3. **One DispatchSource per directory.** Rejected because recursive project trees create avoidable descriptor and lifecycle complexity.
4. **Plain path persistence.** Rejected because it cannot provide sandbox-compatible least-privilege access or stale/repair state.

## Decision

Phase 2 will wrap FSEvents in a narrow adapter. Its C callback immediately copies paths/flags into Sendable event values, then submits them to a per-project actor. `mustScanSubDirs`, user-dropped, kernel-dropped, and root-changed flags require a full rescan/recovery transition. FSEvents integration fixtures use a workspace-backed test directory rather than `/tmp`.

Persist folder selection as security-scoped bookmark data. Resolve it on launch, balance start/stop access calls, and surface `needsRepair` for stale, corrupt, inaccessible, or missing access. Repair replaces bookmark data while retaining the project identity and other settings.

## Consequences

- Positive: efficient native monitoring with explicit recovery and least-privilege folder handling.
- Negative: FSEvents remains coalesced rather than per-operation; app logic must treat it as an invalidation signal.
- Follow-up: Phase 2 requires fake-event tests, workspace integration tests, debounce/coalescing tests, a stale-bookmark repair UI test, and a manual physical sleep/wake release test.

## Verification

`docs/modernization/evidence/monitoring/fsevents-bookmark-prototype.md` contains the real workspace-event, root-change, burst, bookmark restore/stale, corrupt-bookmark, and physical sleep/wake results.
