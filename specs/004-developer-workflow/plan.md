# Implementation Plan: Developer Workflow and Daily Usability

**Branch**: `004-developer-workflow` | **Date**: 2026-07-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-developer-workflow/spec.md`

## Summary

Phase 3 adds an optional, structured build-before-reload path while preserving Phase 2 behavior for projects without a build. The core package will own validated build configuration, one actor-owned child-process lifecycle per project, bounded output, timeout/cancellation, and build/reload coalescing. The app target will compose those services into build configuration, activity, menu-bar, settings, and recovery surfaces. All process execution remains executable-plus-arguments; no shell interpolation is introduced.

## Technical Context

**Language/Version**: Swift 6.2 with complete strict-concurrency checking

**Primary Dependencies**: Foundation `Process`/`Pipe`, SwiftUI/Observation, OSLog, existing `LiveReloadCore`; Apple frameworks only and no new third-party dependencies

**Storage**: Existing versioned JSON project configuration in Application Support, extended with optional build configuration and validated global settings; active build state and raw output remain bounded in memory

**Testing**: Swift Testing/XCTest core unit and integration tests, fixture executables, temporary workspaces, XCUITest for settings/menu/recovery, `scripts/verify-modern.sh`, focused package/app commands

**Target Platform**: Apple-silicon macOS 15+; private locally signed Hardened Runtime preview

**Project Type**: Native macOS desktop application with a local Swift package core

**Performance Goals**: At most one active build per project; one follow-up build per active-build event window; bounded output/history; five-minute idle CPU below 1% for two projects and one browser; no orphan child process after supported lifecycle tests

**Constraints**: No `/bin/sh` invocation; loopback-only browser endpoint remains unchanged; one owner for every process, monitor, listener, and project pipeline; no blocking I/O on the main actor; bounded untrusted arguments, environment values, output, paths, and diagnostics; compiler presets, shell mode, launch-at-login implementation, App Sandbox, broad network exposure, public distribution, and extension bundling deferred

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

- `BuildConfiguration` is a value type owned by the project configuration. It stores an executable URL, ordered arguments, working directory, environment additions, timeout, and enabled state; it never stores a shell command string.
- `BuildRunner` is an actor with one owned `Process` and output readers. It copies pipe data immediately, bounds output by bytes/lines, classifies launch/exit/timeout/cancel results, and performs graceful-then-forced termination on cancellation or timeout.
- `ProjectPipeline` remains the sole owner of one project's monitor/build/reload ordering. A settled batch starts one build when enabled, accumulates changes while running, starts one follow-up batch after completion, and broadcasts only for success. No-build projects retain the Phase 2 immediate reload path.
- `ProjectStore` remains the only persistence owner. Decoding applies constructor invariants and migration defaults; active processes, raw output, and client/runtime state are not persisted.
- `AppModel` remains `@MainActor`, projects immutable projections and validation errors, and gates project/runtime mutations. It does not run process I/O or poll for status.
- Menu-bar commands and the main window use one shared command routing surface so the same action cannot diverge by presentation context.

### Boundary decisions

1. **Structured process boundary.** The default mode passes executable and argument array directly to `Process`; a shell mode is absent. Environment additions are explicit, validated keys and redacted values.
2. **Deterministic build state machine.** States are queued, running, succeeded, failed, cancelled, timed-out, and stopped. Start, stop, cancellation, project removal, and app termination are idempotent and observable.
3. **Bounded diagnostics.** Output and activity history use documented byte/event limits. Summaries contain project-relative paths and result metadata, never full environments, credentials, or unrelated source contents.
4. **Failure isolation.** A build failure suppresses only that project's reload and leaves unrelated projects running. A launch/port/folder/lifecycle recovery state preserves configuration and exposes repair/retry/correction.
5. **Settings precedence.** Global defaults apply first; per-project values override only their supported fields; explicit project exclusions remain evaluated by the existing documented rule precedence. Migration never silently discards unknown data.

### Deferred boundaries

- Compiler/package-manager presets, explicit shell mode, launch-at-login implementation, App Sandbox, public distribution, extension bundling, broad network exposure, and URL override remain outside this feature.
- Durable raw stdout, environment snapshots, automatic project discovery, and automatic monitoring restoration remain out of scope.

## Delivery Sequence

1. Define value types, validation, persistence migration, settings defaults, and contracts; add failing fixtures for invalid configuration and result classification.
2. Implement actor-owned `BuildRunner` with bounded streams, timeout, cancellation, and fixture executable integration tests.
3. Extend `ProjectPipeline` to serialize build and reload, coalesce active-build changes, preserve no-build behavior, and prove no overlap/orphans.
4. Integrate configuration/editor, build activity, visible states, and recovery actions into the app model and SwiftUI surfaces.
5. Add menu-bar command routing, settings/ignore UI, accessibility identifiers, and UI tests with the main window closed.
6. Update guides, ledgers, changelog/inclusion records, phase evidence, and run Debug/Release plus focused and full verification gates.

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
├── Sources/LiveReloadCore/
│   ├── Models/RuntimeModels.swift
│   ├── Persistence/ProjectStore.swift
│   ├── Pipeline/ProjectPipeline.swift
│   ├── Process/BuildConfiguration.swift
│   ├── Process/BuildRunner.swift
│   └── Diagnostics/ActivityStore.swift
└── Tests/LiveReloadCoreTests/
    ├── BuildConfigurationTests.swift
    ├── BuildRunnerTests.swift
    ├── ProjectPipelineTests.swift
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
