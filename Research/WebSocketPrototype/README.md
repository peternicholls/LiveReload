# WebSocket Prototype

Purpose: test whether the current Apple platform stack can serve the required LiveReload protocol scenarios on loopback.

The prototype remains isolated from production code. Its required scenarios and promotion rules are defined by `specs/001-discovery-baseline/contracts/prototype-boundaries.md`.

Build with `swift build -Xswiftc -warnings-as-errors`; run `node scripts/exercise.mjs` after building. The exercise uses only Node.js standard library modules as a raw RFC 6455 client and leaves no production dependency behind.
