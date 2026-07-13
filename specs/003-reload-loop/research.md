# Phase 0 Research: Minimum Useful Reload Loop

## Decision 1: Monitor selected roots with direct FSEvents

- **Decision**: Use direct FSEvents behind an injectable `FileEventSource` boundary, with one actor-owned stream per active project.
- **Rationale**: ADR-002 and its workspace-backed prototype prove recursive events, bounded bursts, root-change recovery, scoped bookmark behavior, and stop cleanup. Polling would increase idle cost and latency; one directory source per subtree would create needless lifecycle complexity.
- **Lifecycle**: The callback copies paths and flags into bounded Sendable values immediately. Start and stop are idempotent. Root-changed, scan-required, user-dropped, and kernel-dropped signals enter recovery and stop the stream; they never silently continue as active monitoring.
- **Alternatives rejected**: Polling (resource and latency cost), per-directory file descriptors (recursive ownership complexity), and plain-path access (does not satisfy least privilege or repairability).

## Decision 2: Treat events as invalidations and settle them with a deterministic batcher

- **Decision**: Normalize every path relative to the selected root, filter it, then de-duplicate and order it inside a 250 ms settling interval. The interval is configurable only within the 100–500 ms product range and uses an injected clock in tests.
- **Rationale**: FSEvents is coalesced and does not promise an operation log. A single settled decision avoids reload storms while keeping the behavior testable.
- **Recovery**: A recovery signal clears pending paths and transitions to recovery without emitting a reload. The user must restore folder access or restart monitoring.
- **Alternatives rejected**: Immediate reload per event (flicker and duplicate refreshes), fixed sleeps in tests (flaky), and trying to reconstruct a full tree diff from lost events in this phase (would make unverified assumptions).

## Decision 3: Use a small owned RFC 6455 server with protocol 7 messages

- **Decision**: Implement the accepted ADR-001 design with Darwin BSD sockets as the local-only TCP transport. The owned server validates the HTTP upgrade and `/livereload` path, supports bounded RFC 6455 frames, and negotiates typed protocol-7 messages.
- **Rationale**: The Network.framework prototype did not provide the needed explicit route boundary and had inconsistent Safari behavior, so `Network.framework` is excluded from this server implementation rather than used beneath the owned protocol parser. An owned BSD-socket implementation makes masking, size bounds, ping/pong, close, client isolation, and diagnostics testable without a dependency.
- **Limits**: Plan exact header, frame, message, and client-count ceilings as named constants with tests. Their numeric values are implementation details, but every untrusted allocation must have a ceiling.
- **Alternatives rejected**: Network.framework server (Safari and route-boundary evidence), external package (unneeded dependency), and legacy Node service (constitution violation).

## Decision 4: Define a deliberately small ignore-rule language

- **Decision**: Match normalized project-relative paths with `/`, `*`, `**`, `?`, and trailing-directory `/` patterns. Evaluate default exclusions before user rules; any matching rule excludes the path. Hidden files are included unless matched.
- **Rationale**: This covers common repository, dependency, build-output, editor-temporary, and project-specific exclusions while remaining explainable and fixture-testable.
- **Defaults**: Exclude version-control metadata, common package/dependency directories, build-output directories, and common editor temporary names. Preserve hidden source files by default.
- **Alternatives rejected**: Full gitignore compatibility (large semantic surface, negation/escaping ambiguity), extension-only filtering (cannot express directory and project rules), and opaque platform predicates (not portable or testable).

## Decision 5: Keep runtime state out of persisted project configuration

- **Decision**: Keep the Phase 1 stored project model stable. Represent active monitor, recovery, last settled batch, local server, and browser count as runtime service/view state; do not restore active monitoring after relaunch.
- **Rationale**: The feature requires an explicit user start, while persisting active runtime resources would create unsafe restart semantics. Existing folder access repair and project-enabled configuration remain the prerequisites for a new session.
- **Alternatives rejected**: Persist active sessions (could restart monitoring without renewed user intent), encode client details (privacy and stale-state risk), and alter Phase 1 storage solely for runtime display state (unnecessary migration risk).

## Decision 6: Reload classification is conservative

- **Decision**: A stylesheet-only batch requests live stylesheet refresh; any other meaningful batch requests a full page refresh. Manual refresh always requests a full page refresh.
- **Rationale**: This matches observed browser compatibility and avoids claiming image or URL-override behavior not verified in this feature.
- **Alternatives rejected**: Classify every extension now (would outrun compatibility evidence), and always use live stylesheet refresh (incorrect for HTML/JS/unknown changes).

## Result

All technical-context decisions are resolved. No `NEEDS CLARIFICATION` item blocks task generation.
