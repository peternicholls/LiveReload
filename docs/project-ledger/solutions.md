# Solution Ledger

Record verified fixes and diagnostic techniques that are likely to be useful again. A solution is not `verified` until its regression test or repeatable verification passes.

## SOL-001 — Reject opaque WebSocket server behavior in favor of owned bounded framing

- Status: verified
- Verified: 2026-07-12
- Solves: ISS-002
- Related tasks: T026–T031, T043
- Related ADRs: ADR-001
- Context: The Network.framework prototype passed raw-client tests but produced inconsistent Safari reload acknowledgement.
- Root cause: The framework path does not expose a sufficient HTTP route/upgrade boundary for the product and the browser fixture exposed inconsistent behavior.
- Solution: Select a minimal owned RFC 6455 server with explicit loopback/path/frame/lifecycle handling.
- Verification: `Research/WebSocketPrototype/scripts/exercise.mjs`; Safari/Chrome fixture observations; ADR-001.
- Rejected alternatives: Continue with Network.framework | cross-browser behavior and route diagnostics are insufficient for v1.
- Limits: The owned server is planned for Phase 2 and must still pass fuzz, browser, and lifecycle tests.
- References: `docs/modernization/evidence/websocket/network-framework-prototype.md`

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

No solutions recorded yet.
