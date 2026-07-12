# Issue Ledger

Record product defects, blockers, risks, and unanswered technical questions here. Keep newest open issues first. Do not use this file for planned work already represented by a task unless something unexpected occurs.

## Open

### ISS-001 — Archived binary observation lacks the required isolated runtime

- Status: blocked
- Severity: low
- Found: 2026-07-11
- Owner: Phase 0 maintainer
- Related tasks: T015
- Related ADRs: none
- Reproduction: The archived Intel application requires a disposable account or isolated environment, restricted networking, no private mounts, and no credentials before execution.
- Expected: Runtime observation should occur only under the safeguards required by constitution Article IV.7.
- Actual: This workspace has no verified disposable/isolated user environment, so launching the archived bundle would not meet the safety gate.
- Evidence: `.specify/memory/constitution.md`; `docs/modernization/behavior-inventory.md`
- Hypotheses: Source and historical tests provide sufficient interim evidence for Phase 0 behavior classification.
- Next action: Revisit only if a disposable, network-restricted macOS environment becomes available; otherwise retain source/test evidence.
- Review/expiry: 2026-10-11

### ISS-002 — Network.framework prototype has inconsistent Safari reload evidence

- Status: resolved
- Severity: medium
- Found: 2026-07-11
- Owner: Phase 0 maintainer
- Related tasks: T026, T028, T029, T030, T031
- Related ADRs: ADR-001
- Reproduction: Connect current Safari and Chrome through `Research/BrowserFixture/?wsPort=35732` to the Network.framework WebSocket prototype, then send repeated `reload` messages through the prototype stdin.
- Expected: Every connected fixture client acknowledges each reload message.
- Actual: Raw RFC 6455 clients and Chrome completed the scenario. Safari completed protocol hello but did not emit reload acknowledgement for repeated broadcasts in this prototype run.
- Evidence: `Research/WebSocketPrototype/scripts/exercise.mjs`; `docs/modernization/evidence/websocket/network-framework-prototype.md`
- Hypotheses: Network.framework’s server-side framing/connection lifecycle is not transparent enough for the required cross-browser protocol and path-validation behavior.
- Next action: Use the accepted minimal owned RFC 6455 server decision in ADR-001; retain the Network.framework harness as regression evidence only.
- Review/expiry: 2026-10-11

<!--
### ISS-002 — Concise problem statement

- Status: open
- Severity: medium
- Found: YYYY-MM-DD
- Owner: unassigned
- Related tasks: T000
- Related ADRs: ADR-000
- Reproduction: exact steps or fixture path
- Expected: observable expected behavior
- Actual: observable actual behavior
- Evidence: command, log path, screenshot, or test name
- Hypotheses: bounded list; distinguish fact from inference
- Next action: one concrete step
- Review/expiry: YYYY-MM-DD (required for accepted risk or exception)
-->

## Resolved or Accepted

Move records here without changing their IDs. Add resolution date, linked solution/commit/test, and why the disposition is justified.

### ISS-003 — Physical sleep/wake monitoring exercise requires an interactive desktop window

- Status: resolved
- Severity: low
- Found: 2026-07-12
- Resolved: 2026-07-12
- Owner: Phase 0 maintainer
- Related tasks: T036
- Related ADRs: ADR-002
- Reproduction: Start a workspace-backed FSEvents monitor, put the physical Mac to sleep, wake it, and verify monitoring restarts without duplicate streams or missed recovery state.
- Expected: The lifecycle remains single-owned and recovers cleanly after wake.
- Actual: After normal sleep/wake and unlock, a workspace-fixture edit emitted an event and the monitor stopped once.
- Evidence: `docs/modernization/evidence/monitoring/sleep-wake-capture.log`; `docs/modernization/evidence/monitoring/fsevents-bookmark-prototype.md`
- Resolution: Interactive validation passed; the capture is sanitized and retained in the repository.
- Next action: Repeat this manual exercise as a release check on a future production monitor.
- Review/expiry: 2026-10-11
