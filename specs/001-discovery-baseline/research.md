# Research Strategy and Current Decisions

## Decision 1: Use observable behavior as the compatibility baseline

- **Decision:** Build a classified behavior inventory from legacy source/tests and safe runtime observation; do not treat the old architecture as a porting specification.
- **Rationale:** The goal is to preserve useful outcomes while removing obsolete runtimes and dependencies.
- **Alternatives considered:** Line-by-line port (rejected: carries obsolete boundaries); feature invention from memory (rejected: lacks evidence).
- **Evidence to collect:** Repository file/line references, legacy test cases, captured runtime observations, and future verification method.

## Decision 2: Validate browser compatibility before choosing server implementation

- **Decision:** Create a standalone browser fixture and capture Safari/Chromium protocol behavior before evaluating the Swift server prototype.
- **Rationale:** This keeps client expectations independent of server assumptions and yields reusable acceptance fixtures.
- **Alternatives considered:** Implement server first (rejected: may encode incorrect assumptions); ship a new extension (rejected for v1 scope).
- **Evidence to collect:** Browser/version, client source/version, endpoint, handshake, reload message, CSS/page behavior, and captured trace/result.

## Decision 3: Prototype Network.framework first, retain a bounded fallback

- **Decision:** Attempt server-side WebSocket handling using current Apple SDK capability. If required framing, control frames, multiple clients, or diagnostics are inadequate, evaluate a minimal local RFC 6455 subset before considering a dependency.
- **Rationale:** Apple frameworks best satisfy the minimal-dependency constitution, but feasibility must be executable rather than assumed.
- **Alternatives considered:** Third-party WebSocket package (deferred pending demonstrated need); resurrect Node server (rejected by constitution and scope).
- **Evidence to collect:** Bind/path handling, handshake, reload exchange, multiple clients, disconnect, malformed frames, port collision, latency, and API limitations.

## Decision 4: Use FSEvents with an explicit concurrency adapter

- **Decision:** Prototype FSEvents directly, copy callback data immediately into typed Sendable values, and separately demonstrate bookmark lifecycle/repair.
- **Rationale:** FSEvents is the appropriate macOS tree-monitoring primitive, while callback ownership and permission restoration are the risk boundaries.
- **Alternatives considered:** Polling (rejected as primary due to resource/latency trade-offs); DispatchSource per directory (rejected for large recursive trees).
- **Evidence to collect:** Create/modify/rename/delete, coalescing, dropped events, root change, stop/restart, sleep/wake, bookmark restoration/staleness/repair.

## Decision 5: Keep research harnesses disposable

- **Decision:** Place prototypes in `Research/` and prohibit production imports until a later phase deliberately reimplements or promotes verified pieces through its own plan/tasks.
- **Rationale:** Research code optimizes for learning; production code must optimize for lifecycle, tests, accessibility, and maintainability.
- **Alternatives considered:** Build prototypes directly in the app target (rejected: encourages accidental architecture lock-in).

## Decision 6: Private preview with explicit distribution boundary

- **Decision:** Research a locally signed, hardened-runtime private preview; keep App Sandbox and public distribution as later explicit decisions.
- **Rationale:** Arbitrary developer build tools complicate sandboxing, while public distribution changes legal, signing, notarization, and support obligations.
- **Alternatives considered:** Mac App Store from v1 (rejected as out of scope); unsigned-only development (rejected because signing behavior must be understood).

## Primary-source research requirements

- Apple documentation and installed SDK headers for Network.framework, FSEvents, bookmarks, hardened runtime, signing, and `SMAppService` where relevant.
- Maintained LiveReload protocol/client repositories and published protocol documentation.
- The repository's licence, history, source, and tests for historical behavior and attribution.
- Exact browser/app/tool versions recorded alongside every observation.

## Research completion rule

A research item is complete only when it produces an ADR, fixture, compatibility row, benchmark, or reproducible observation. Notes without a decision or evidence do not close a task.
