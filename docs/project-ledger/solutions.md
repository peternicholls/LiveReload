# Solution Ledger

Record verified fixes and diagnostic techniques that are likely to be useful again. A solution is not `verified` until its regression test or repeatable verification passes.

## SOL-001 — Reject opaque WebSocket server behavior in favor of owned bounded framing

- Status: verified
- Verified: 2026-07-12
- Solves: ISS-002
- Related tasks: Phase 0 T026–T031; `specs/003-reload-loop/tasks.md` T022–T032
- Related ADRs: ADR-001
- Context: The Network.framework prototype passed raw-client tests but produced inconsistent Safari reload acknowledgement.
- Root cause: The framework path does not expose a sufficient HTTP route/upgrade boundary for the product and the browser fixture exposed inconsistent behavior.
- Solution: Select a minimal owned RFC 6455 server with explicit loopback/path/frame/lifecycle handling.
- Verification: `Research/WebSocketPrototype/scripts/exercise.mjs`; Safari/Chrome fixture observations; ADR-001.
- Rejected alternatives: Continue with Network.framework | cross-browser behavior and route diagnostics are insufficient for v1.
- Limits: The Phase 2 server implements the bounded monitoring subset only; browser-client serving, URL override, broad-network access, and exhaustive security fuzzing remain outside this feature.
- References: `docs/modernization/evidence/websocket/network-framework-prototype.md`; `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/ReloadServerTests.swift`; Phase 2 browser evidence index

## SOL-002 — Fence asynchronous resource work at the actor-owned lifecycle boundary

- Status: verified
- Verified: 2026-07-14
- Solves: ISS-006
- Related tasks: T012, T013, T020, T026, T027, T031, T032
- Related ADRs: ADR-001, ADR-002
- Context: File streams, socket sessions, debounce sleeps, and browser broadcasts complete asynchronously and may race a stop or recovery transition.
- Root cause: Actor serialization alone does not invalidate work that suspends and later resumes; descriptor callbacks also require one queue-owned close/read state.
- Solution: Give lifecycle operations a generation, re-check it after every suspension, keep descriptor/source mutation on one serial owner, own and cancel pending batch/broadcast tasks, translate event-buffer overflow into recovery, and bound concurrent fan-out.
- Verification: `MonitoringTests.swift`, `ProjectPipelineTests.swift`, `ReloadServerTests.swift`, and `RuntimeTestDoubleTests.swift`; 90-test Phase 2 core suite.
- Rejected alternatives: Rely on actor isolation without cancellation generations | suspended work can resume after the lifecycle changes.
- Limits: Phase 3 process execution will need its own child-process cancellation proof; it must not assume these socket/stream fences cover subprocesses.
- References: commits `98f6668d` and `9d843b55`; ISS-006

<!--
## SOL-001 — Concise solution name

- Status: verified
- Verified: YYYY-MM-DD
- Solves: ISS-001
- Related tasks: R-00.0
- Related ADRs: ADR-000
- Context: conditions where this applies
- Root cause: evidence-backed explanation
- Solution: concise implementation or diagnostic steps
- Verification: test names and exact commands
- Rejected alternatives: option | reason
- Limits: cases this does not cover
- References: commit, files, primary documentation
-->
