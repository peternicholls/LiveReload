# Learning Ledger

Capture non-obvious discoveries that should affect later design, estimation, testing, or support. Promote architectural consequences into an ADR rather than hiding them here.

## LRN-001 — Network.framework exposes server-side WebSocket support but is not the selected production boundary

- Status: validated
- Learned: 2026-07-11
- Related tasks/issues: T027–T031, ISS-002
- Observation: The installed macOS SDK exposes `NWProtocolWebSocket.Options`, a client-request handler, message-size limit, and text-frame metadata. The Swift prototype built under strict concurrency and passed raw handshake, broadcast, malformed-input, disconnect, and port-collision scenarios; Safari reload acknowledgement remained inconsistent in the cross-browser fixture run.
- Interpretation: Framework capability alone is insufficient for the app’s requirements: explicit `/livereload` routing, predictable handshake observability, and cross-browser diagnostics require a smaller owned boundary.
- Consequence: ADR-001 selects a minimal local RFC 6455 loopback server with bounded frames and explicit HTTP upgrade/path validation.
- Evidence: `Research/WebSocketPrototype/`; `docs/modernization/evidence/websocket/network-framework-prototype.md`; installed Network.framework `ws_options.h`.
- Revisit when: Apple documents and demonstrates a stable server-side path/handshake API with Safari compatibility evidence that satisfies the same fixture.

## LRN-002 — FSEvents needs workspace-backed integration fixtures and explicit recovery semantics

- Status: validated
- Learned: 2026-07-12
- Related tasks/issues: T032–T038
- Observation: The direct FSEvents adapter reported create/modify/rename/delete and root-change events for a workspace fixture root; a 10,000-write burst produced six bounded records. The same adapter did not receive events for the `/tmp` test root in this environment.
- Interpretation: Production integration tests must use a real workspace/Application Support-backed temporary directory, not assume `/tmp` event behavior. Root-change, dropped-event, and user/kernel-drop flags must trigger a full rescan/restart path.
- Consequence: ADR-002 adopts a narrow FSEvents adapter that copies events into Sendable values, debounces in a project actor, and treats recovery flags as rescan signals.
- Evidence: `Research/FSEventsPrototype/`; `docs/modernization/evidence/monitoring/fsevents-bookmark-prototype.md`.
- Revisit when: The app supports volumes with different event-stream guarantees or the integration test host changes.

<!--
## LRN-002 — Concise learning

- Status: validated
- Learned: YYYY-MM-DD
- Related tasks/issues: T000, ISS-000
- Observation: what was directly observed
- Interpretation: what the observation probably means
- Consequence: how future work changes
- Evidence: fixture, test, benchmark, documentation, or commit
- Revisit when: condition that would invalidate or supersede this learning
-->
