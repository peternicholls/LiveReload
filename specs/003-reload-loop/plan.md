# Implementation Plan: Minimum Useful Reload Loop

**Branch**: `003-reload-loop` | **Date**: 2026-07-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-reload-loop/spec.md`

## Summary

Phase 2 delivers the first useful LiveReload outcome: a user explicitly starts monitoring an enabled project, meaningful file changes are filtered and settled into one batch, and compatible browsers connected through the local-only endpoint receive one protocol-7 reload message. The design adds actor-owned monitoring, browser connection, and pipeline services to `LiveReloadCore`, with the app target remaining responsible for composition and presentation. Existing project persistence, bookmark repair, diagnostics, and Phase 1 UI boundaries remain intact.

## Technical Context

**Language/Version**: Swift 6.2 with complete strict-concurrency checking

**Primary Dependencies**: Foundation, CoreServices FSEvents through a narrow adapter, Darwin BSD socket primitives for the owned loopback TCP listener, SwiftUI/Observation in the app target, OSLog; no third-party dependencies

**Storage**: Existing versioned JSON project configuration in Application Support; runtime monitoring/session/client state is in-memory and is not restored as active after relaunch

**Testing**: Swift Testing/XCTest core unit and integration tests; workspace-backed FSEvents fixture; raw WebSocket and Safari/Chromium browser fixtures; XCUITest for visible monitoring and recovery states; `scripts/verify-modern.sh`

**Target Platform**: Apple-silicon macOS 15+; private locally signed Hardened Runtime preview

**Project Type**: Native macOS desktop application with a local Swift package core

**Performance Goals**: Change bursts settle in a documented 100–500 ms window; a 10,000-event burst is bounded and de-duplicated; one active project remains below 1% CPU over a five-minute idle sample

**Constraints**: Loopback-only endpoint; protocol-7 compatibility; one owner for each monitor, listener, client, and project pipeline; no blocking I/O on the main actor; bounded untrusted paths, frames, messages, and diagnostics; builds, broad network exposure, App Sandbox, public distribution, extension bundling, and URL override remain deferred

**Scale/Scope**: One app target, one local core package, one project pipeline per actively monitored project, multiple local browser clients, and no build command execution

## Constitution Check

### Pre-design gate

| Principle / gate | Phase 2 design response | Result |
|---|---|---|
| Behavior before implementation | Uses behavior-inventory records BEH-004–BEH-006 and BEH-011–BEH-012 plus Phase 0 browser fixtures | PASS |
| Native, modern, minimal | Uses Apple frameworks and a small owned protocol implementation; no runtime package or legacy process | PASS |
| Safe concurrency and ownership | Each monitor, server, connection, and pipeline has explicit actor ownership and idempotent lifecycle | PASS |
| Security and privacy | Endpoint is loopback-only; browser data, file paths, and diagnostics are validated, bounded, and redacted | PASS |
| Evidence-driven delivery | Tests, browser fixtures, idle sample, release validation, and recovery evidence are planned before implementation | PASS |
| Accessible/actionable experience | Active, stopped, recovering, permission-loss, root-loss, and port-conflict states have UI and keyboard acceptance | PASS |
| Durable project memory | This feature receives its own spec, plan, task ledger, evidence, and phase review | PASS |
| Scope/attribution/release integrity | Existing notices and release posture remain; no new third-party inclusion is planned | PASS |

**Pre-design verdict:** PASS. No constitutional exception is requested.

## Architecture and Design

### Runtime ownership

```text
SwiftUI views + AppModel (@MainActor)
        │ user intent and immutable presentation state
        ▼
LiveReloadCore actors
  ├── ProjectMonitor ── FSEvents adapter ── project bookmark scope
  ├── ChangeBatcher ─── default/user exclusions + injectable clock
  ├── ReloadServer ──── loopback listener + browser sessions
  └── ProjectPipeline ─ monitor batch → reload decision → broadcast
        │
        ▼
typed, bounded, Sendable events and safe activity summaries
```

- `ProjectMonitor` is the sole owner of one project's FSEvents stream and its scoped folder-access lifetime. Its callback copies raw values immediately into bounded `FileChangeSignal` values before entering actor isolation.
- `ChangeBatcher` belongs to a project pipeline. It applies path normalization and exclusion policy before maintaining one ordered, de-duplicated pending batch. It uses an injected clock to make settling and cancellation deterministic in tests.
- `ReloadServer` owns the `127.0.0.1` BSD-socket listener, port-conflict result, and browser session registry. Every `BrowserSession` owns one RFC 6455 connection and has a bounded handshake/message state machine. `Network.framework` is not used for the server in this phase; ADR-001 rejected that option on route-boundary and Safari-compatibility evidence.
- `ProjectPipeline` owns the monitor-to-reload decision for one project. It serializes start, stop, recovery, manual reload, settled batches, and server broadcasts. There is no build branch in this feature.
- `AppModel` owns only presentation state and launches owned service operations. It derives controls from service states and keeps project mutations separate from runtime operations.
- `ProjectStore` remains the sole persistence owner. Runtime session state and browser connections are deliberately not persisted; monitoring always starts from an explicit user action after launch.

### Boundary decisions

1. **Filesystem events are invalidation signals, not a file-operation log.** Root changes, lost events, and scan-required flags move a monitor to recovery; the app must not claim it is watching until the user completes the documented recovery path.
2. **Ignore rules apply to normalized project-relative paths.** Default exclusions are evaluated first, then user exclusions; a matching rule excludes a path. Hidden files remain included unless matched. The grammar is rooted glob matching with `/`, `*`, `**`, `?`, and a trailing `/` for a directory subtree; escaping and negated rules are excluded from this phase.
3. **The browser endpoint has one local compatibility contract.** It binds `127.0.0.1:35729`, accepts only `/livereload`, requires a compatible protocol-7 hello, requires masked client frames, and bounds HTTP headers, frames, messages, and client count. It supports text, close, ping, and pong only.
4. **Reload decisions are conservative.** A stylesheet-only batch emits a live stylesheet refresh; every other supported batch and manual refresh emits a full page reload. A recovery signal, excluded-only batch, stopped project, or absent compatible client emits no reload.
5. **Failure isolation is mandatory.** A malformed client, disconnection, or write failure closes only that session. A port conflict leaves project configuration and monitoring intact while exposing a retryable server state. Folder and stream failures preserve configuration and point to repair/restart actions.

### Deferred boundaries

- Build command execution, build output, cancellation, and build-gated reload remain Phase 3 work.
- Automatic monitoring restoration, launch at login, menu-bar-only workflow, App Sandbox, public distribution, extension bundling, URL override, and broad network exposure remain outside this feature.
- Recursive rescan contents are not inferred from raw event-loss flags in this feature. The monitor enters recovery rather than issuing an unverified reload.

## Delivery Sequence

1. Extend core model fixtures and define runtime monitoring, change, reload, and client value contracts without changing Phase 1 persistence behavior.
2. Add deterministic fake-event monitoring and exclusion/debounce behavior with unit and temporary-workspace integration tests before the production adapter.
3. Add the owned bounded protocol-7/RFC-6455 server with raw-frame lifecycle tests before app composition.
4. Add the per-project pipeline and prove monitor-to-reload behavior against the existing browser fixtures.
5. Integrate monitoring, connection, manual reload, activity, and recovery states into the SwiftUI app and UI tests.
6. Extend release verification and phase evidence with browser, idle, privacy, recovery, and compatibility results.

## Post-design Constitution Check

| Principle / gate | Design artifact evidence | Result |
|---|---|---|
| Behavior and scope | [research.md](./research.md), BEH-004–BEH-006, BEH-011–BEH-012, ADR-001/002 | PASS |
| Data/service boundaries | [data-model.md](./data-model.md), [monitoring-service.md](./contracts/monitoring-service.md), [reload-protocol.md](./contracts/reload-protocol.md) | PASS |
| Ownership and lifecycle | Monitoring, server, session, and pipeline lifecycle contracts | PASS |
| Privacy and diagnostics | [reload-protocol.md](./contracts/reload-protocol.md), [ui-states.md](./contracts/ui-states.md) | PASS |
| User recovery/accessibility | [ui-states.md](./contracts/ui-states.md), [quickstart.md](./quickstart.md) | PASS |
| Verification and release integrity | [quickstart.md](./quickstart.md), task-level evidence gates | PASS |

**Post-design verdict:** PASS. No complexity exception or constitutional amendment is required.

## Project Structure

### Documentation (this feature)

```text
specs/003-reload-loop/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
├── contracts/
│   ├── monitoring-service.md
│   ├── ignore-rules.md
│   ├── reload-protocol.md
│   └── ui-states.md
└── tasks.md
```

### Source Code (repository root)

```text
Packages/LiveReloadCore/
├── Sources/LiveReloadCore/
│   ├── Models/
│   ├── Persistence/
│   ├── FolderAccess/
│   ├── Diagnostics/
│   ├── Monitoring/
│   ├── ReloadProtocol/
│   ├── ReloadServer/
│   └── Pipeline/
└── Tests/LiveReloadCoreTests/
    ├── MonitoringTests.swift
    ├── IgnoreRuleTests.swift
    ├── ReloadProtocolTests.swift
    ├── ReloadServerTests.swift
    └── ProjectPipelineTests.swift

ModernLiveReload/
├── LiveReloadApp/
│   ├── AppModel.swift
│   ├── Services/
│   └── Views/
├── LiveReloadAppTests/
└── LiveReloadAppUITests/

tests/fixtures/reload-loop/
├── monitoring/
├── protocol/
└── browser/
```

**Structure Decision**: The core package owns all durable domain, monitoring, protocol, server, and pipeline behavior so it can be tested without SwiftUI. AppKit remains limited to existing folder selection; SwiftUI stays in the app target. Tests use fakes at the monitoring clock/source boundary and raw/browser fixtures at the protocol boundary.

## Complexity Tracking

No constitutional violations require justification.
