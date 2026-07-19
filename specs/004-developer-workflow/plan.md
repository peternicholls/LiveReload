# Implementation Plan: Developer Workflow and Daily Usability

**Branch**: `004-developer-workflow` | **Date**: 2026-07-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-developer-workflow/spec.md`

## Summary

Phase 3 adds an optional, structured build-before-reload path while preserving Phase 2 no-build and manual-reload behavior. The core package will own validated build configuration, one actor-owned process-group lifecycle per project, numeric output/history limits, timeout/cancellation, and deterministic build/reload coalescing. The app target will compose those services into build configuration, activity, menu-bar, settings, and recovery surfaces. All process execution remains executable-plus-arguments; no shell interpolation is introduced.

## Technical Context

**Language/Version**: Swift 6.2 with complete strict-concurrency checking

**Primary Dependencies**: Foundation `Process`/`Pipe`, a narrow Darwin process-control adapter for forced descendant teardown, SwiftUI/Observation, OSLog, existing `LiveReloadCore`; Apple frameworks only and no new third-party dependencies

**Storage**: Existing versioned JSON project configuration in Application Support, extended with optional build configuration and validated global settings; active build state and raw output remain bounded in memory

**Testing**: Swift Testing/XCTest core unit and integration tests, fixture executables, temporary workspaces, XCUITest for settings/menu/recovery, `scripts/verify-modern.sh`, focused package/app commands

**Target Platform**: Apple-silicon macOS 15+; private locally signed Hardened Runtime preview

**Project Type**: Native macOS desktop application with a local Swift package core

**Performance Goals**: At most one active build per project; one follow-up build per active-build event window unless lifecycle cancellation discards it; 1 MiB live output per run, 4 KiB per terminal activity summary, 50–500 retained activity events, and at most 5 MiB logical diagnostic payload for two maximum-output builds plus 500 summaries; five-minute mean idle CPU below 1% for two projects and one browser; no orphan process in the owned fixture process group after supported lifecycle tests

**Constraints**: No `/bin/sh` invocation in production; loopback-only browser endpoint remains unchanged; one owner for every process group, monitor, listener, and project pipeline; no blocking I/O on the main actor; numeric bounds from the specification apply to untrusted arguments, environment values, output, paths, and diagnostics; working directories remain within the selected project root; compiler presets, shell mode, launch-at-login implementation, automatic monitoring restoration, App Sandbox, broad network exposure, public distribution, and extension bundling deferred

**Scale/Scope**: One app target, one local core package, multiple active projects and local browsers, one serialized build pipeline per project, and five user stories covering build workflow and daily controls

## Constitution Check

### Pre-design gate

| Principle / gate | Phase 3 design response | Result |
|---|---|---|
| Behavior before implementation | User stories retain no-build reload behavior and define observable build, failure, menu, settings, and recovery outcomes | PASS |
| Native, modern, minimal | Uses Foundation process primitives and existing Apple UI/storage boundaries; no dependency added | PASS |
| Safe concurrency and ownership | `BuildRunner` and `ProjectPipeline` have explicit actor ownership, idempotent lifecycle, and one active build per project | PASS |
| Security and privacy | Executable-plus-arguments only; executable, working directory, environment, output, and diagnostics are validated/bounded/redacted | PASS |
| Evidence-driven delivery | Fixture executables, coalescing tests, UI tests, lifecycle checks, performance evidence, and release verification are planned | PASS |
| Accessible/actionable experience | Build and recovery states, menu commands, settings, and errors have keyboard/VoiceOver and non-color-only acceptance | PASS |
| Durable project memory | This spec receives design artifacts, task ledger, evidence, and phase-review updates; ledger changes are part of delivery | PASS |
| Scope/attribution/release integrity | No public distribution or new asset/dependency is introduced; roadmap remains the phase authority | PASS |
| Versioning, inclusions, and living guides | User/developer guides, changelog, inclusion register, and phase evidence are updated at the sprint gate | PASS |

**Pre-design verdict:** PASS. No constitutional exception is requested.

## Architecture and Design

### Runtime ownership

```text
SwiftUI views + AppModel (@MainActor)
        │ validated user intent and immutable projections
        ▼
LiveReloadCore actors
  ├── ProjectPipeline ── monitor batch + build gate + reload decision
  │     └── BuildRunner ── Process/Pipe + timeout + cancellation
  ├── ProjectStore ──── versioned configuration and settings persistence
  └── existing monitor/server actors ── file events and browser clients
        │
        ▼
bounded Sendable build results, activity events, and recovery actions
```

- The existing placeholder `BuildConfiguration` is replaced and moved from `Models/ProjectConfiguration.swift` into `Process/BuildConfiguration.swift` without introducing a duplicate declaration. It remains a value owned by project configuration and stores an executable URL, ordered arguments, project-contained working directory, environment additions, timeout, and enabled state; it never stores a shell command string.
- `BuildRunner` is an actor with one owned process group and output readers. A narrow Darwin-backed process-group adapter supplements Foundation `Process` where descendant termination requires it. Pipe data is copied immediately, bounded by the numeric contract, classified by launch/exit/timeout/cancel result, and terminated graceful-then-forced on cancellation or timeout.
- `ProjectPipeline` remains the sole owner of one project's monitor/build/reload ordering. A settled batch starts one build when enabled and accumulates changes while running. Success, launch failure, nonzero exit, timeout, and run-only cancellation start exactly one pending follow-up while the project remains enabled and watching; lifecycle cancellation discards pending work. Only success broadcasts. No-build projects retain the Phase 2 immediate reload path.
- `ProjectStore` remains the only persistence owner. Decoding applies constructor invariants and migration defaults; active processes, raw output, and client/runtime state are not persisted.
- `AppModel` remains `@MainActor`, projects immutable projections and validation errors, and gates project/runtime mutations. It does not run process I/O or poll for status.
- Menu-bar commands and the main window use one shared command routing surface so the same action cannot diverge by presentation context. `Reload Now` deliberately preserves the Phase 2 immediate manual broadcast, clearly bypasses build gating, and leaves active and pending build batches unchanged.

### Boundary decisions

1. **Structured process boundary.** The default mode passes executable and argument array directly to `Process`; a shell mode is absent. Environment additions are explicit, validated keys and redacted values.
2. **Deterministic build state machine.** States are queued, running, succeeded, failed, cancelled, timed-out, and stopped. **Cancel Current Build** is available only while running and may start one pending follow-up; pause, stop, access loss, project removal, and app termination discard pending work. Graceful termination has a 2-second maximum before forced process-group termination. Every transition is idempotent and observable.
3. **Bounded diagnostics.** Live output is capped at 1 MiB per run, displayed lines at 16 KiB, terminal summaries at 4 KiB, and activity history at 50–500 events (default 200). With two maximum-output active runs and 500 maximum summaries, logical retained diagnostic payload remains at or below 5 MiB. Summaries contain project-relative paths and result metadata, never full environments, credentials, or unrelated source contents.
4. **Failure isolation and redaction.** A build failure suppresses only that project's reload and leaves unrelated projects running. A launch/port/folder/lifecycle recovery state preserves configuration and exposes repair/retry/correction. Configuration/activity metadata omit argument and environment values; captured output redacts exact nonempty configured environment values before it is bounded and displayed.
5. **Settings precedence and migration.** Fixed built-in exclusions apply first, custom global patterns second, and per-project patterns third; any match excludes, and preview identifies the matching layer. Reset clears custom global patterns but preserves fixed and per-project rules. `showMainWindow` and `menuBarOnly` affect presentation only. Known older schema fields migrate through explicit defaults, unsupported future schemas remain write-protected, and preservation of unknown keys inside the current schema is not promised by the typed JSON envelope.
6. **Path access.** Phase 3 reuses the selected project's existing scoped folder access for the working directory and rejects a directory that resolves outside that root. Because App Sandbox remains deferred, the executable is stored as a standardized file URL rather than a new bookmark and is revalidated as a regular executable file immediately before launch; a legitimate in-place replacement is allowed.
7. **Network/lifecycle recovery.** Sleep, wake, and network/path transition notifications may trigger idempotent reconciliation, but they never broaden the loopback endpoint or create a second listener, monitor, process group, or pending build.

### Deferred boundaries

- Compiler/package-manager presets, explicit shell mode, launch-at-login implementation, App Sandbox, public distribution, extension bundling, broad network exposure, and URL override remain outside this feature.
- Durable raw stdout, environment snapshots, automatic project discovery, and automatic monitoring restoration remain out of scope. Launch behavior only chooses main-window or menu-bar-only presentation on a user-initiated launch.

## Delivery Sequence

1. Replace the existing placeholder build type; define validation, persistence migration, settings defaults, numeric limits, and contracts; add failing fixtures for invalid configuration and result classification.
2. Implement actor-owned `BuildRunner` with an owned process group, bounded streams, timeout, cancellation, descendant cleanup, and deterministic Swift fixture-executable integration tests.
3. Extend `ProjectPipeline` to serialize build and reload, coalesce active-build changes, preserve no-build behavior, and prove no overlap/orphans.
4. Integrate configuration/editor, build activity, visible states, and recovery actions into the app model and SwiftUI surfaces.
5. Add menu-bar command routing, settings/ignore UI, accessibility identifiers, and UI tests with the main window closed.
6. Extend `scripts/verify-modern.sh` for Phase 3 fixture, evidence, privacy, build-to-browser, resource, and documentation integrity; update guides, ledgers, changelog/inclusion records, phase evidence, and run Debug/Release plus focused and full verification gates.

## Project Structure

### Documentation (this feature)

```text
specs/004-developer-workflow/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
├── contracts/
│   ├── build-execution.md
│   ├── pipeline-gating.md
│   └── menu-settings-recovery.md
└── tasks.md
```

### Source Code (repository root)

```text
Packages/LiveReloadCore/
├── Sources/
│   ├── LiveReloadBuildFixture/main.swift
│   └── LiveReloadCore/
│       ├── Models/ConfigurationEnvelope.swift
│       ├── Models/RuntimeModels.swift
│       ├── Models/Settings.swift
│       ├── Persistence/ProjectStore.swift
│       ├── Pipeline/ProjectPipeline.swift
│       ├── Process/BuildConfiguration.swift
│       ├── Process/BuildRunner.swift
│       ├── Process/BuildRunnerSupport.swift
│       └── Diagnostics/ActivityStore.swift
└── Tests/LiveReloadCoreTests/
    ├── BuildConfigurationTests.swift
    ├── BuildRunnerTests.swift
    ├── BuildPipelineStressTests.swift
    ├── ProjectPipelineTests.swift
    ├── RecoveryLifecycleTests.swift
    ├── SettingsTests.swift
    └── RuntimePersistenceCompatibilityTests.swift

ModernLiveReload/LiveReloadApp/
├── AppModel.swift
├── Views/ProjectRuntimeViews.swift
├── Views/ProjectViews.swift
├── Views/MenuBarViews.swift
├── Views/SettingsViews.swift
└── Services/ReloadLoopRuntimeService.swift

ModernLiveReload/LiveReloadAppTests/
ModernLiveReload/LiveReloadAppUITests/
tests/fixtures/developer-workflow/
├── builds/
├── configuration/
└── lifecycle/
scripts/verify-modern.sh
```

**Structure Decision**: Core owns process, pipeline, persistence, and test doubles; the app target owns composition and presentation; fixtures provide deterministic process and lifecycle evidence. Existing files are extended before new abstractions are introduced.

## Post-design Constitution Check

| Principle / gate | Design artifact evidence | Result |
|---|---|---|
| Behavior and scope | [research.md](./research.md), [build-execution.md](./contracts/build-execution.md) | PASS |
| Data/service boundaries | [data-model.md](./data-model.md), [pipeline-gating.md](./contracts/pipeline-gating.md) | PASS |
| Ownership and lifecycle | BuildRunner and ProjectPipeline contracts plus cancellation tests | PASS |
| Privacy and diagnostics | Bounded/redacted output and recovery contract | PASS |
| User recovery/accessibility | [menu-settings-recovery.md](./contracts/menu-settings-recovery.md), [quickstart.md](./quickstart.md) | PASS |
| Verification and release integrity | Quickstart and task evidence gates | PASS |
| Versioning, inclusions, and living guides | Documentation and ledger tasks in final phase | PASS |

**Post-design verdict:** PASS. No complexity exception or constitutional amendment is required.

## Complexity Tracking

No constitutional violations require justification.
