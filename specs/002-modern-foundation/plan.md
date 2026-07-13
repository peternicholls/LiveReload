# Implementation Plan: Modern Foundation

**Branch**: `002-modern-foundation` | **Date**: 2026-07-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-modern-foundation/spec.md`

## Summary

Phase 1 creates the native, testable base for the rewrite: a SwiftUI macOS shell and a UI-free Swift package that owns versioned project configuration, atomic local persistence, security-scoped folder access, and bounded/redacted activity records. It delivers an accessible project lifecycle—add, inspect, rename, enable, repair, and remove—without claiming filesystem monitoring, browser reload, or build execution.

## Technical Context

**Language/Version**: Swift 6.2 with complete strict-concurrency checking

**Primary Dependencies**: SwiftUI, Observation, Foundation, OSLog, AppKit only through a narrow folder-picker bridge; no third-party dependencies

**Storage**: Versioned JSON configuration in Application Support, written atomically; security-scoped bookmark data stored only inside project records

**Testing**: Swift Testing/XCTest for `LiveReloadCore`; temporary-directory integration tests; XCUITest for project lifecycle/accessibility; `xcodebuild` shell verification

**Target Platform**: Apple-silicon macOS 15+; private locally signed Hardened Runtime preview, not App Sandbox or public distribution

**Project Type**: Native macOS desktop application with a local Swift package core

**Performance Goals**: Activity history remains bounded to 200 events and no synchronous disk I/O runs on the main actor. Quantitative launch/load targets require a separately specified performance criterion and are not claimed in Phase 1.

**Constraints**: arm64 only; warnings are errors in Debug and Release; no legacy runtimes/dependencies; project paths/bookmarks are untrusted input; diagnostics never retain full absolute paths, source contents, credentials, or environments; all mutable persistence state has one actor owner

**Scale/Scope**: One macOS app target, one local core package, one UI-test target, four user stories, and no production monitoring/network/build service in this feature

## Constitution Check

### Pre-design gate

| Principle / gate | Phase 1 design response | Result |
|---|---|---|
| Behavior before implementation | Retains only Phase 0-approved project/access outcomes; no legacy source is ported | PASS |
| Native, modern, minimal | SwiftUI + Foundation/OSLog/AppKit bridge; no third-party or legacy runtime | PASS |
| Safe concurrency and ownership | `ProjectStore` is an actor; UI model is `@MainActor`; same-project UI mutations are gated; bookmark scope is explicitly balanced | PASS |
| Security and privacy | Atomic data, validated configuration, least-privilege bookmarks, bounded/redacted events | PASS |
| Evidence-driven delivery | Unit, integration, UI, architecture, signing, and clean-account checks are planned before completion | PASS |
| Accessible/actionable experience | Empty, repair, missing-folder, and removal states have keyboard/VoiceOver acceptance checks | PASS |
| Durable project memory | Feature task ledger, issue/solution/learning linkage, and Sprint 1/2 reviews are mandatory | PASS |
| Scope/attribution/release integrity | Private hardened-runtime posture from ADR-003 retained; public/sandbox work deferred | PASS |

**Pre-design verdict:** PASS. No constitutional exception is requested.

## Architecture and Design

### Boundary model

```text
SwiftUI views + AppModel (@MainActor)
        │ user intent / immutable view state
        ▼
LiveReloadCore services
  ├── ProjectStore actor ───── versioned JSON in Application Support
  ├── FolderAccessProvider ─── security-scoped bookmark adapter
  ├── ActivityStore actor ──── bounded, redacted ActivityEvent values
  └── Project validation ───── normalized folder identity and model invariants
        ▲
        └── typed results/errors, never raw path/secret diagnostics
```

- `LiveReloadCore` has no SwiftUI/AppKit import. It owns domain models, validation, migration, persistence protocols, fake providers, and service tests.
- `LiveReloadApp` is an Xcode app target. Its `@MainActor` `AppModel` coordinates UI state, owns per-project pending-operation state, and invokes core services with explicit `Task` ownership. A project accepts at most one mutation at a time while operations for distinct project IDs remain independent.
- AppKit appears only in `FolderPicker` to obtain a user-selected URL. The core receives an URL/provider result, not an `NSOpenPanel`.
- `ProjectStore` serializes load/mutate/save. It writes a temporary sibling file, flushes/replaces atomically, and preserves corrupt input under a timestamped diagnostic name before returning an empty/recoverable state.
- `FolderAccessProvider` has real and fake implementations. The real implementation creates/resolves bookmarks and returns a scoped-access token whose release balances `startAccessingSecurityScopedResource`.
- `ActivityStore` accepts only already-redacted values, retains the newest 200 events, and exposes snapshots for the UI.
- `VERSIONING.md`, `CHANGELOG.md`, the software-inclusion register, and the living guides are project-wide governance sources. `scripts/verify-modern.sh` will verify their required state at Phase 1 exit; release tags and app marketing/build versions share one future target-owned version source.

### Deferred boundaries

- FSEvents is deferred to Phase 2 under ADR-002; Phase 1 stores only monitoring-state placeholders.
- The owned loopback RFC 6455 server and protocol-7 model are deferred to Phase 2 under ADR-001.
- Build-command validation/execution is deferred to Phase 3; Phase 1 stores a non-executable placeholder configuration only.
- App Sandbox/public-distribution work is deferred under ADR-003. Hardened Runtime/private signing remains required for app-target verification.
- `ProjectDetailView` section extraction is deferred until section growth creates a concrete reuse or navigation boundary; splitting the current small form would add indirection without changing behavior.
- A queued banner/toast presentation layer is deferred until recoverable messages require stacking or non-modal dismissal. Write-protected configuration failures use a dedicated blocking state; transient recoverable notices retain the single-alert Phase 1 contract.

## Delivery Sequence

1. Establish project, package, schemes, deployment/signing/concurrency policy, and one repeatable verification command.
2. Implement the pure model layer and its fixture-driven tests before UI/persistence services.
3. Add `ProjectStore` atomic persistence and `FolderAccessProvider` lifecycle with fake-provider tests, then workspace-backed integration checks.
4. Add `ActivityEvent` redaction/capacity behavior and connect safe service outcomes to it.
5. Build the SwiftUI project-list flow around the tested core; add accessibility identifiers and XCUITest coverage.
6. Run Debug/Release, test, architecture, signing, privacy, and clean-account evidence; update ledgers and sprint review before Phase 2 handoff.

## Post-design Constitution Check

| Principle / gate | Design artifact evidence | Result |
|---|---|---|
| Behavior and scope | [research.md](./research.md) records deferred services and ADR inheritance | PASS |
| Data/service boundaries | [data-model.md](./data-model.md), store and access contracts | PASS |
| Ownership and lifecycle | [folder-access.md](./contracts/folder-access.md), [project-store.md](./contracts/project-store.md) | PASS |
| Privacy and diagnostics | [activity-events.md](./contracts/activity-events.md) | PASS |
| User recovery/accessibility | [ui-states.md](./contracts/ui-states.md), quickstart acceptance checks | PASS |
| Verification and release integrity | [quickstart.md](./quickstart.md) | PASS |

**Post-design verdict:** PASS. No complexity exception or constitutional amendment is required.

## Project Structure

### Documentation (this feature)

```text
specs/002-modern-foundation/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/requirements.md
├── contracts/
│   ├── project-store.md
│   ├── folder-access.md
│   ├── activity-events.md
│   └── ui-states.md
└── tasks.md
```

### Source code (created during implementation)

```text
ModernLiveReload/
├── LiveReload.xcodeproj/
├── LiveReloadApp/
│   ├── LiveReloadApp.swift
│   ├── AppModel.swift
│   ├── Views/
│   ├── Bridges/FolderPicker.swift
│   └── Resources/
├── LiveReloadAppTests/
└── LiveReloadAppUITests/

Packages/LiveReloadCore/
├── Package.swift
├── Sources/LiveReloadCore/
│   ├── Models/
│   ├── Persistence/
│   ├── FolderAccess/
│   └── Diagnostics/
└── Tests/LiveReloadCoreTests/

scripts/verify-modern.sh
tests/fixtures/modern-foundation/
VERSIONING.md
CHANGELOG.md
docs/guides/
docs/project-ledger/software-inclusions.md
```

**Structure Decision**: The app target contains only presentation/composition concerns. The local package is the source of truth for all durable domain and service behavior. This preserves testability and prevents phase-specific AppKit/SwiftUI leakage into later monitoring, protocol, and build services.

## Complexity Tracking

No constitutional violations require justification.

## Phase Exit and Handoff

Phase 1 closes only when the following are evidenced in the Sprint 1/2 review:

1. The documented verification command builds Debug/Release and runs core/UI tests with warnings as errors.
2. The app launches as arm64 on macOS 15+ and has private hardened-runtime signing evidence.
3. Model, store, bookmark, diagnostics, and project-list acceptance criteria pass independently.
4. No critical/high security issue is open; configuration recovery and access repair are actionable and privacy-safe.
5. All completed tasks link to fixtures/tests/evidence, and ledgers/ADRs reflect any new decision.
6. Version/changelog, software-inclusion, NOTICE, user-guide, and developer-guide review evidence is complete for every claimed Phase 1 capability.
7. Phase 2 begins with a fresh `speckit.specify` flow for `reload-loop` rather than appending monitoring/server work here.
8. Post-review hardening adds test-first per-project mutation gating without broadening the Phase 1 feature surface.
