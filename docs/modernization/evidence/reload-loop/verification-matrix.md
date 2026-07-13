# Phase 2 Reload Loop Verification Matrix

The matrix defines the evidence required to close each Phase 2 gate. `Planned`
means the command or capture remains to be run after its owning implementation
tasks; it is not a passing result.

| Gate | Required verification | Evidence destination | Blocking rule | Current state |
|---|---|---|---|---|
| Core Debug | `swift test` with Swift 6 strict concurrency and warnings treated as errors | Core test transcript summarized in Sprint 2 review | Any failure, warning, or skipped required test blocks | Planned |
| Core Release | `swift build -c release` with warnings treated as errors | Release build summary | Any failure or warning blocks | Planned |
| Integration | Disposable workspace FSEvents, raw RFC 6455, pipeline, and recovery tests | Core integration summary | Missing lifecycle, bounds, or isolation scenario blocks | Planned |
| Browser | Production server exercised by Safari and Chromium fixtures | Sanitized compatibility record | Either browser missing or any incompatible negotiation/reload blocks | Planned |
| App Debug/Release | Shared Xcode scheme built in both configurations | `scripts/verify-modern.sh` summary | Any failure or warning blocks | Planned |
| UI/accessibility | App-model and UI tests for monitoring, connection, manual reload, recovery, keyboard, and VoiceOver state | UI test summary | Missing state/control coverage or failure blocks | Planned |
| Idle/resources | Thirty-second warm-up followed by 300 one-second CPU samples; monitor/server lifecycle cleanup | Sanitized mean, peak, and cleanup record | Mean CPU at or above 1%, incomplete sample, or retained resource blocks | Planned |
| Privacy | Scan captured diagnostics/evidence and exercise bounded path/message cases | Privacy review record | Secret, absolute private path, bookmark, peer address, raw untrusted input, or unrelated contents block | Planned |
| Recovery | Folder loss, event loss, root change, port conflict, malformed/oversized client, disconnect, and restart | Recovery matrix | Configuration loss, false active state, or cross-client/project failure blocks | Planned |
| Documentation/release | Requirements checklist, guides, changelog, inclusion/NOTICE disposition, constitution and final analysis | Sprint 2 review and evidence index | Missing or contradictory artifact blocks | Planned |

## Setup evidence

- Sanitized input fixtures: `tests/fixtures/reload-loop/`
- Pre-implementation analysis: `cross-artifact-analysis.md`
- Accepted browser reference: `Research/BrowserFixture/`
- Accepted server decision: `docs/adr/001-websocket-server.md`
- Accepted monitoring decision: `docs/adr/002-monitoring-and-folder-access.md`

