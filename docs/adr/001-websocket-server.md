# ADR-001: Own the minimal LiveReload RFC 6455 server

- Status: accepted
- Date: 2026-07-11
- Deciders: Phase 0 maintainer
- Related tasks/issues: T026–T031, ISS-002, LRN-001
- Supersedes: none

## Context

The modern app needs a loopback-only WebSocket endpoint that validates the `/livereload` upgrade, negotiates protocol 7, handles bounded malformed input, tracks clients, broadcasts reload messages, closes cleanly, and behaves consistently in current Safari and Chrome.

## Decision drivers

- Cross-browser behavior observed through the Phase 0 fixture.
- Explicit control of HTTP upgrade/path validation, frame limits, lifecycle, and diagnostics.
- No third-party production dependency and no embedded Node runtime.

## Considered options

1. **Network.framework `NWProtocolWebSocket` server.** It has current SDK support and passed raw-client/Chrome scenarios, but the prototype lacks the required explicit route boundary and yielded inconsistent Safari reload acknowledgement.
2. **Small local RFC 6455 implementation.** It requires careful bounded parsing and tests, but makes the HTTP upgrade, `/livereload` path, masking, payload limit, close/ping handling, and broadcast lifecycle explicit.
3. **Third-party WebSocket package.** Rejected because the existing platform/owned implementation options satisfy the requirement without licence, maintenance, binary-size, and removal cost.
4. **Legacy Node server.** Rejected by the constitution and product scope.

## Decision

Implement a small local RFC 6455 server in the Phase 2 `reload-loop` feature. It binds only `127.0.0.1`, accepts only `/livereload`, limits frame/message sizes, requires masked client frames, supports text, close, ping, and pong control frames, and uses typed protocol-7 messages. Reuse the Phase 0 browser fixture and raw-frame scenarios as acceptance tests.

## Consequences

- Positive: path validation, handshake diagnostics, memory limits, and cross-browser behavior are explicit and testable.
- Negative: the project owns RFC 6455 edge cases and must test them thoroughly.
- Follow-up: Phase 2 must implement protocol fuzz/property tests, two-client broadcast, port conflict, disconnect cleanup, and Safari/Chrome end-to-end fixtures before claiming compatibility.

## Verification

- `Research/WebSocketPrototype/scripts/exercise.mjs` passed raw handshake, reload, multiple-client, malformed-input, disconnect, and port-collision scenarios.
- `docs/modernization/evidence/websocket/network-framework-prototype.md` records the Safari inconsistency that invalidates the framework option for v1.
