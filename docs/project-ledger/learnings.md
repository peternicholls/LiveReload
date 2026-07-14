# Learning Ledger

Capture non-obvious discoveries that should affect later design, estimation, testing, or support. Promote architectural consequences into an ADR rather than hiding them here.

## LRN-001 — Network.framework exposes server-side WebSocket support but is not the selected production boundary

- Status: validated
- Learned: 2026-07-11
- Related tasks/issues: T027–T031, ISS-002
- Observation: The installed macOS SDK exposes `NWProtocolWebSocket.Options`, a client-request handler, message-size limit, and text-frame metadata. The Swift prototype built under strict concurrency and passed raw handshake, broadcast, malformed-input, disconnect, and port-collision scenarios; Safari reload acknowledgement remained inconsistent in the cross-browser fixture run.
- Interpretation: Framework capability alone is insufficient for the app’s requirements: explicit `/livereload` routing, predictable handshake observability, and cross-browser diagnostics require a smaller owned boundary.
- Consequence: ADR-001 selects a minimal local RFC 6455 loopback server with bounded frames and explicit HTTP upgrade/path validation.
- Evidence: `Research/WebSocketPrototype/`; `docs/modernization/evidence/websocket/network-framework-prototype.md`; installed Network.framework `ws_options.h`; Phase 2 raw-server and production-browser fixtures.
- Revisit when: Apple documents and demonstrates a stable server-side path/handshake API with Safari compatibility evidence that satisfies the same fixture.

## LRN-002 — FSEvents needs workspace-backed integration fixtures and explicit recovery semantics

- Status: validated
- Learned: 2026-07-12
- Related tasks/issues: T032–T038
- Observation: The direct FSEvents adapter reported create/modify/rename/delete and root-change events for a workspace fixture root; a 10,000-write burst produced six bounded records. The same adapter did not receive events for the `/tmp` test root in this environment.
- Interpretation: Production integration tests must use a real workspace/Application Support-backed temporary directory, not assume `/tmp` event behavior. Root-change, dropped-event, and user/kernel-drop flags must stop truthful watching and enter an explicit recovery/restart path.
- Consequence: ADR-002 adopts a narrow FSEvents adapter that copies events into Sendable values and debounces in a project actor. Phase 2 stops the stream and surfaces recovery for loss flags; it does not infer unobserved tree contents or claim a recursive rescan.
- Evidence: `Research/FSEventsPrototype/`; `docs/modernization/evidence/monitoring/fsevents-bookmark-prototype.md`.
- Revisit when: The app supports volumes with different event-stream guarantees or the integration test host changes.

## LRN-003 — Actor ownership needs explicit invalidation across suspension points

- Status: validated
- Learned: 2026-07-14
- Related tasks/issues: T012, T020, T026, T027, T031, T032, ISS-006
- Observation: A monitor start, debounce wait, socket write, or broadcast can suspend while stop or recovery changes the owner's state. Actor isolation serializes each continuation but does not make the earlier intent current when it resumes.
- Interpretation: Every owned background operation needs an invalidation token or cancellation boundary, and callback-driven descriptors need one serialized owner for read, close, and source cancellation.
- Consequence: Phase 2 uses lifecycle generations, owned cancellable tasks, serial session state, explicit overflow recovery, and bounded concurrent broadcasts. Phase 3 must apply the same rule to build-process lifetime.
- Evidence: concurrency regressions in `MonitoringTests.swift`, `ProjectPipelineTests.swift`, `ReloadServerTests.swift`, and `RuntimeTestDoubleTests.swift`; SOL-002.
- Revisit when: Swift provides stronger structured-lifetime primitives that remove the need for explicit generation checks at these boundaries.

## LRN-004 — Runtime truth belongs in event-driven services, not project persistence

- Status: validated
- Learned: 2026-07-14
- Related tasks/issues: T014, T028, T033
- Observation: Monitor, server, client-count, and reload activity can change independently of saved project configuration and must respond immediately to resource lifecycle events.
- Interpretation: Persisting or polling those values would create false active states after relaunch and widen race windows with project mutations.
- Consequence: `ReloadLoopRuntimeService` owns resource composition and publishes bounded updates; `AppModel` projects them on the main actor and shares per-project operation gates with configuration mutations. Monitoring always requires explicit user start after launch.
- Evidence: `LiveReloadAppTests.swift`, `LiveReloadAppUITests.swift`, and `ReloadLoopRuntimeService.swift`.
- Revisit when: A later specification explicitly designs automatic restoration and proves crash/relaunch ownership semantics.

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
