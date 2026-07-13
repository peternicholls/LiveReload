# Network.framework WebSocket Prototype Evidence

- **Tasks:** T026–T031
- **Date:** 2026-07-11
- **SDK evidence:** `Network.framework/Headers/ws_options.h` and the installed Swift interface expose WebSocket v13 options, server client-request handler, maximum message size, metadata, and response types.

## Build verification

```text
swift build -Xswiftc -warnings-as-errors
Build complete! (0.65s)

swift build -c release -Xswiftc -warnings-as-errors
Build complete! (2.29s)
```

## Raw RFC 6455 exercise

```text
node scripts/exercise.mjs
PASS bind hello reload multiple-clients malformed-input disconnect port-collision
```

The exercise creates two masked WebSocket clients, validates server `hello`, sends malformed JSON, broadcasts a reload through stdin, closes clients, and verifies a second listener exits with code 2 for port collision.

## Browser fixture observation

- Chrome 149 completed hello and reload acknowledgement through the Network.framework prototype.
- Safari 26.5.2 completed hello but did not acknowledge repeated reload broadcasts in the fixture run.
- The prototype has no explicit production-quality HTTP route boundary for `/livereload`.

## Result

Network.framework is rejected as the v1 production server implementation. The prototype is retained as evidence, while ADR-001 selects a minimal owned RFC 6455 server with explicit loopback/path validation and the same browser fixture as an acceptance test.
