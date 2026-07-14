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

## SOL-003 — Bound loopback browser trust before protocol readiness

- Status: verified
- Verified: 2026-07-14
- Solves: ISS-007
- Related tasks: T026, T030, T031, T032, T037
- Related ADRs: ADR-001
- Context: Loopback binding prevents remote-host access, but an unrelated browser origin can still initiate a WebSocket connection and an incomplete local client can consume a bounded session slot.
- Root cause: The upgrade parser did not evaluate `Origin`, and accepted sessions had no lifetime bound before completing protocol-7 negotiation.
- Solution: Permit absent Origin for native/raw compatibility, allow only exact loopback HTTP(S) browser origins, reject malformed/opaque/duplicate origins, and give each connected or HTTP-upgraded non-ready session a serial-queue-owned two-second deadline that cancels on ready or close.
- Verification: `ReloadProtocolTests.swift` origin matrix; `ReloadServerTests.swift` live rejection, saturation expiry, and ready-client survival; production Safari/Chromium compatibility; independent dynamic security re-audit.
- Rejected alternatives: Treat loopback binding as sufficient | browsers can reach loopback from unrelated web origins. Allow sessions to wait indefinitely within the 32-client cap | incomplete peers can deny service without exceeding any allocation bound.
- Limits: A malicious native process can repeatedly reconnect or negotiate as a raw client; broader authentication or capability tokens require a separate local-threat model and compatibility decision.
- References: ISS-007; `docs/modernization/evidence/reload-loop/security-privacy-review.md`

## SOL-004 — Make end-to-end evidence cross every claimed production boundary

- Status: verified
- Verified: 2026-07-14
- Solves: ISS-008
- Related tasks: T024, T030, T037, T039
- Related ADRs: ADR-001, ADR-002
- Context: Component tests can prove monitoring, settlement, pipeline decisions, protocol delivery, and browsers independently while still leaving their production composition untested.
- Root cause: The first compatibility harness injected typed decisions directly at `ReloadServer`, so its result was incorrectly combined with separate pipeline tests to support an end-to-end file-save claim.
- Solution: Build the acceptance harness from the same production services as the app, drive behavior at the user boundary with disposable workspace writes, inject failure while real clients remain connected, and make the verifier reject lower-level shortcuts.
- Verification: A regression run timed out on the old direct harness; two strengthened Safari/Chromium runs and `RUN_BROWSER_COMPATIBILITY_GATE=1 scripts/verify-modern.sh` passed after remediation.
- Rejected alternatives: Treat a chain of separate green component tests as equivalent | it cannot detect wiring, lifecycle, or classification gaps between those components.
- Limits: The harness intentionally excludes deferred build execution and browser-extension packaging; those later features require their own complete production paths.
- References: ISS-008; commit `10d0792e`; `docs/modernization/evidence/reload-loop/browser-compatibility-2026-07-14.md`

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
