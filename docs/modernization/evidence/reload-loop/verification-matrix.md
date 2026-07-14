# Phase 2 Reload Loop Verification Matrix

The matrix records the evidence used to close each Phase 2 gate. The
authoritative full repository gate completed successfully on 2026-07-14; the
Sprint 2 review links the consolidated results.

| Gate | Required verification | Evidence destination | Blocking rule | Current state |
|---|---|---|---|---|
| Core Debug | `swift test` with Swift 6 strict concurrency and warnings treated as errors | 92 tests in 7 suites; `sprint-2.md` | Any failure, warning, or skipped required test blocks | Pass |
| Core Release | `swift build -c release` with warnings treated as errors | Successful production build; `sprint-2.md` | Any failure or warning blocks | Pass |
| Integration | Disposable workspace FSEvents, raw RFC 6455, pipeline, and recovery tests | Core integration summary in `sprint-2.md` | Missing lifecycle, bounds, or isolation scenario blocks | Pass |
| Browser | Production server exercised by Safari and Chromium fixtures | `browser-compatibility-2026-07-14.md` | Either browser missing or any incompatible negotiation/reload blocks | Pass |
| App Debug/Release | Shared Xcode scheme built in both configurations | `scripts/verify-modern.sh`; `sprint-2.md` | Any failure or warning blocks | Pass |
| UI/accessibility | App-model and UI tests for monitoring, connection, manual reload, recovery, keyboard, and VoiceOver state | 10 app and 10 UI tests; `sprint-2.md` | Missing state/control coverage or failure blocks | Pass |
| Idle/resources | Thirty-second warm-up followed by 300 one-second CPU samples; monitor/server lifecycle cleanup | `idle-resources.md` | Mean CPU at or above 1%, incomplete sample, or retained resource blocks | Pass |
| Privacy | Scan captured diagnostics/evidence and exercise bounded path/message cases | `security-privacy-review.md`; repository verifier | Secret, absolute private path, bookmark, peer address, raw untrusted input, or unrelated contents block | Pass |
| Recovery | Folder loss, event loss, root change, port conflict, malformed/oversized client, disconnect, and restart | Integration/UI summary in `sprint-2.md` | Configuration loss, false active state, or cross-client/project failure blocks | Pass |
| Documentation/release | Requirements checklist, guides, changelog, inclusion/NOTICE disposition, constitution and final analysis | `sprint-2.md`, evidence index, and `final-cross-artifact-analysis.md` | Missing or contradictory artifact blocks | Pass |

## Setup evidence

- Sanitized input fixtures: `tests/fixtures/reload-loop/`
- Pre-implementation analysis: `cross-artifact-analysis.md`
- Final closure analysis: `final-cross-artifact-analysis.md`
- Accepted browser reference: `Research/BrowserFixture/`
- Accepted server decision: `docs/adr/001-websocket-server.md`
- Accepted monitoring decision: `docs/adr/002-monitoring-and-folder-access.md`
