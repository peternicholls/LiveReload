---
description: "Dependency-ordered Phase 1 modern foundation tasks"
---

# Tasks: Modern Foundation

**Input**: Design documents from `/specs/002-modern-foundation/`
**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`, and `quickstart.md`
**Roadmap mapping**: This file is the authoritative executable ledger for Phase 1. Parent roadmap IDs remain in task descriptions for cross-phase traceability.

## Format

- `[ ] TNNN [P?] [US?] Description with exact output path`
- `[>]` means in progress or awaiting a documented external validation; `[!]` means blocked; `[x]` means completed with evidence.
- **[P]** marks tasks that may run in parallel after their listed prerequisites are complete.
- A completed task includes its named acceptance evidence; unexpected work is recorded as an `ISS-NNN` ledger entry.

## Phase 1: Foundation and Governance

**Purpose**: Create the isolated modern target boundaries and verification scaffolding before durable behavior is implemented.

- [ ] T001 Confirm `002-modern-foundation` begins from merged `develop`; record the base SHA and Phase 1 start in `docs/modernization/sprint-reviews/sprint-1.md`.
- [ ] T002 [P] Create the Sprint 1/2 review record from the project template at `docs/modernization/sprint-reviews/sprint-1.md` with constitution/version, capacity, and evidence sections.
- [ ] T003 [P] Create Phase 1 fixture and evidence directories: `tests/fixtures/modern-foundation/` and `docs/modernization/evidence/foundation/`, each with a purpose/handling README.
- [ ] T004 [P] Add a Phase 1 ledger-traceability entry template/checkpoint linking task → issue → evidence → solution/learning/ADR → sprint review in `docs/modernization/sprint-reviews/sprint-1.md`.
- [ ] T005 Verify no Phase 1 production source imports legacy targets, Node/Ruby/CoffeeScript, CocoaPods, or third-party packages; record the baseline scan in `docs/modernization/evidence/foundation/dependency-baseline.md` (FR-003, FR-016).

**Checkpoint**: Phase 1 has a clean branch identity, durable evidence locations, and scope guard before code is created.

---

## Phase 2: User Story 2 — Native Verifiable Baseline (Priority: P1)

**Goal**: Establish a reproducible arm64 Swift 6.2 application and UI-free local core.

**Independent Test**: From a clean checkout, one documented command builds Debug/Release and runs core/UI tests with warnings treated as errors; the app launches as arm64.

### Tests and configuration first

- [ ] T006 [US2] Define the exact modern-target verification matrix (Debug/Release, core tests, UI tests, architecture, signing, clean-account smoke) in `docs/modernization/evidence/foundation/verification-matrix.md` before target creation (FR-002, FR-015).
- [ ] T007 [P] [US2] Define modern project naming, bundle-ID/signing placeholders, macOS deployment floor, and no-dependency policy in `ModernLiveReload/README.md` (FR-001–FR-003).
- [ ] T008 [P] [US2] Create `Packages/LiveReloadCore/Package.swift` with an empty core library/test target and compile-only test proving no SwiftUI/AppKit import (FR-001, FR-003).

### Implementation

- [ ] T009 [US2] Create `ModernLiveReload/LiveReload.xcodeproj` with `LiveReloadApp`, `LiveReloadAppTests`, and `LiveReloadAppUITests` targets; link only the local `LiveReloadCore` package (roadmap F-01.1–F-01.2; FR-001, FR-003).
- [ ] T010 [US2] Configure the app and package for Swift 6.2 strict concurrency, arm64-only, macOS 15+, warnings as errors, private Hardened Runtime signing, shared schemes, and stable test plans (roadmap F-01.3; FR-001, ADR-003).
- [ ] T011 [P] [US2] Create minimal `LiveReloadApp.swift` and a launch smoke test in `ModernLiveReload/LiveReloadApp/` and `ModernLiveReload/LiveReloadAppUITests/` (FR-001, SC-002).
- [ ] T012 [US2] Implement `scripts/verify-modern.sh` to build Debug/Release, run package/app/UI tests, inspect arm64/deployment target, and verify signing; make skipped targets fail explicitly (roadmap F-01.4; FR-002, FR-015).
- [ ] T013 [US2] Document modern-only build/run/test commands and legacy-target exclusion in `ModernLiveReload/README.md` and `README.md` (roadmap F-01.5; FR-002–FR-003).
- [ ] T014 [US2] Run the clean-checkout verification matrix and capture commands/results in `docs/modernization/evidence/foundation/build-baseline.md` (SC-001, SC-002).

**Checkpoint**: US2 passes SC-001/SC-002; the app target is native, repeatable, and does not inherit the legacy runtime stack.

---

## Phase 3: Shared Domain Model and Service Contracts

**Purpose**: Implement test-first, UI-independent domain behavior shared by persistence, access, diagnostics, and UI stories.

- [ ] T015 Create failing model fixtures for valid/default/invalid/future-version configuration envelopes in `tests/fixtures/modern-foundation/configuration/` (FR-004–FR-005, FR-015).
- [ ] T016 [P] Create failing fixture cases for duplicate normalized folder identity and configuration-only removal in `tests/fixtures/modern-foundation/projects/` (FR-007, FR-011).
- [ ] T017 [P] Create failing redaction/capacity fixture cases in `tests/fixtures/modern-foundation/activity/` (FR-013–FR-014).
- [ ] T018 Implement `ConfigurationEnvelope`, schema-version validation/migration protocol, and future-version rejection in `Packages/LiveReloadCore/Sources/LiveReloadCore/Models/` (roadmap F-02.1–F-02.2; FR-004–FR-005).
- [ ] T019 [P] Implement `ProjectConfiguration`, `BuildConfiguration`, `IgnoreRule`, `MonitoringState`, and identifier/display-name invariants in `Packages/LiveReloadCore/Sources/LiveReloadCore/Models/` (roadmap F-02.1, F-02.4; FR-004–FR-005, FR-016).
- [ ] T020 [P] Implement `ActivityEvent`, fixed category/severity types, and central path/message redaction policy in `Packages/LiveReloadCore/Sources/LiveReloadCore/Diagnostics/` (roadmap F-03.1; FR-013–FR-014).
- [ ] T021 Add unit tests for model round trips, defaults, invalid data, future-version rejection, stable IDs, placeholders, and redaction fixtures in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/` (roadmap F-02.3, F-03.3; FR-004–FR-005, FR-013–FR-016).
- [ ] T022 Document model invariants, identity semantics, persisted/non-persisted fields, and Phase 2/3 placeholders in `Packages/LiveReloadCore/README.md` (roadmap F-02.4; FR-004–FR-005, FR-016).

**Checkpoint**: Shared models satisfy FR-004/FR-005/FR-013/FR-014 without importing UI frameworks and have fixture-backed tests.

---

## Phase 4: User Story 1 — Restore a Trusted Project List (Priority: P1)

**Goal**: Persist selected projects safely and restore/recover their folder access without data loss.

**Independent Test**: Add a temporary folder, relaunch, verify stable project state; test corrupt/future data, duplicate selection, stale access, and repair with fake and real provider evidence.

### Tests first

- [ ] T023 [US1] Write failing `ProjectStore` temporary-directory integration tests for empty load, atomic round trip, corrupt-file preservation, and future-version rejection in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/` (FR-005–FR-006, FR-015).
- [ ] T024 [P] [US1] Write failing fake `FolderAccessProvider` tests for available, stale, missing, denied, corrupt, duplicate, balanced access, repair success, and repair cancellation in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/` (FR-007–FR-010, FR-015).

### Persistence and access implementation

- [ ] T025 [US1] Implement actor-owned `ProjectStore`, Application Support path resolution, atomic write/replace, typed load outcomes, and corrupt-file quarantine in `Packages/LiveReloadCore/Sources/LiveReloadCore/Persistence/` (roadmap P-01.1–P-01.2; FR-006).
- [ ] T026 [US1] Implement normalized folder-identity duplicate detection and configuration-only removal in `Packages/LiveReloadCore/Sources/LiveReloadCore/Persistence/` (roadmap P-01.3; FR-007, FR-011).
- [ ] T027 [US1] Implement `FolderAccessProvider` protocol, scoped-access token, and fake provider in `Packages/LiveReloadCore/Sources/LiveReloadCore/FolderAccess/` and test support (roadmap P-02.1; FR-008–FR-010).
- [ ] T028 [US1] Implement the production security-scoped bookmark adapter with explicit create/resolve/start/stop/repair behavior in `ModernLiveReload/LiveReloadApp/Services/` or a platform adapter target, keeping AppKit out of `LiveReloadCore` (FR-008–FR-010, ADR-002).
- [ ] T029 [US1] Connect bookmark outcomes to persisted project access state so stale/missing/denied/corrupt conditions preserve the project and require repair in `Packages/LiveReloadCore/` (FR-009–FR-010).
- [ ] T030 [US1] Complete temporary-directory and fake-provider integration tests, including project-identity/settings retention across repair and folder-preserving removal, in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/` (roadmap P-01.4, P-02.2; SC-003, SC-004).
- [ ] T031 [US1] Add a workspace-backed real bookmark integration procedure/result to `docs/modernization/evidence/foundation/folder-access.md` without retaining private paths (roadmap P-02.3; FR-008, FR-015).

**Checkpoint**: US1 passes SC-003/SC-004; no access failure silently deletes project configuration.

---

## Phase 5: User Story 4 — Safe Local Diagnostics (Priority: P2)

**Goal**: Provide bounded, redacted activity history that exposes recoverable local failures safely.

**Independent Test**: Cause storage/access failures through fakes, inspect activity snapshots, and prove capacity/redaction behavior.

- [ ] T032 [US4] Write failing activity-store capacity, category/severity, path-redaction, long-message, and secret-like-fixture tests in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/` (FR-013–FR-015).
- [ ] T033 [US4] Implement actor-owned bounded `ActivityStore` and typed append/snapshot behavior in `Packages/LiveReloadCore/Sources/LiveReloadCore/Diagnostics/` (roadmap F-03.2; FR-013).
- [ ] T034 [US4] Add OSLog category mapping with privacy-safe interpolation in `ModernLiveReload/LiveReloadApp/Diagnostics/` and map store/access outcomes to safe events (roadmap F-03.1; FR-013–FR-014).
- [ ] T035 [US4] Complete diagnostics tests and capture a privacy scan of test fixtures/events in `docs/modernization/evidence/foundation/diagnostics-privacy.md` (roadmap F-03.3; SC-006).

**Checkpoint**: US4 passes SC-006; activity is actionable, bounded, and privacy-safe.

---

## Phase 6: User Story 3 — Manage Projects Accessibly (Priority: P2)

**Goal**: Deliver the user-facing project lifecycle over the tested core and platform adapters.

**Independent Test**: Keyboard/XCUITest adds a temporary folder, renames/enables it, enters/repairs access failure, removes configuration, and confirms the source folder remains.

### Tests and UI states first

- [ ] T036 [US3] Define XCUITest scenarios and accessibility identifiers for empty, available, repair-required, missing-folder, corrupt-store recovery, and removal confirmation states in `ModernLiveReload/LiveReloadAppUITests/` (FR-011–FR-012, FR-015).
- [ ] T037 [P] [US3] Define UI copy and non-color state treatment for each state in `ModernLiveReload/LiveReloadApp/Resources/ProjectLifecycleCopy.md`, aligned with `contracts/ui-states.md` (FR-012).

### UI implementation

- [ ] T038 [US3] Implement `LiveReloadApp`, `AppModel` (`@MainActor`), dependency composition, and `NavigationSplitView` shell in `ModernLiveReload/LiveReloadApp/` (roadmap P-03.1; FR-001, FR-011).
- [ ] T039 [US3] Implement the narrow AppKit `FolderPicker` bridge and add-project flow with duplicate/error mapping in `ModernLiveReload/LiveReloadApp/Bridges/` and `Views/` (roadmap P-03.2; FR-007–FR-012).
- [ ] T040 [US3] Implement project-list/detail/empty views, safe folder labels, rename, enable/disable, repair, and confirmed configuration-only removal in `ModernLiveReload/LiveReloadApp/Views/` (roadmap P-03.2–P-03.3; FR-009–FR-012).
- [ ] T041 [US3] Surface bounded activity history and recovery actions in `ModernLiveReload/LiveReloadApp/Views/` without exposing raw paths or errors (FR-013–FR-014).
- [ ] T042 [US3] Add keyboard support, VoiceOver labels/order, Dynamic Type/layout checks, light/dark appearance behavior, and UI-test identifiers across the project flow (roadmap P-03.4; FR-012).
- [ ] T043 [US3] Implement and run XCUITests for add/rename/enable/repair/remove, empty/error states, accessibility identifiers, and folder-preserving removal in `ModernLiveReload/LiveReloadAppUITests/` (SC-005).

**Checkpoint**: US3 passes SC-005; all project lifecycle states are understandable and actionable without monitoring/network features.

---

## Phase 7: Phase Exit and Handoff

- [ ] T044 [P] Re-run `specs/002-modern-foundation/checklists/requirements.md` against implementation/evidence; correct any regression and record the result in `docs/modernization/sprint-reviews/sprint-1.md`.
- [ ] T045 [P] Run `scripts/verify-modern.sh` from a clean checkout and capture Debug/Release/test/architecture/signing output in `docs/modernization/evidence/foundation/verify-modern.md` (SC-001, SC-002).
- [ ] T046 [P] Run a privacy/provenance scan for credentials, absolute local paths, bookmark bytes, private source contents, unclassified assets, and committed build products; record the sanitized result in `docs/modernization/evidence/foundation/privacy-review.md` (FR-014–FR-015).
- [ ] T047 [P] Perform clean-account/first-launch smoke evidence for empty state, add, relaunch, repair, and removal without using a private source folder; capture procedure/result in `docs/modernization/evidence/foundation/clean-account-smoke.md` (FR-011–FR-015).
- [ ] T048 Link all new ISS/SOL/LRN/ADR records to their originating tasks and evidence; record constitution compliance/exceptions in `docs/modernization/sprint-reviews/sprint-1.md` (SC-007).
- [ ] T049 Run Spec Kit cross-artifact analysis across the feature spec, plan, tasks, constitution, Phase 0 ADRs, and implementation evidence; resolve critical/high findings and save the result in `docs/modernization/evidence/foundation/cross-artifact-analysis.md`.
- [ ] T050 Complete the Phase 1 readiness verdict in `docs/modernization/sprint-reviews/sprint-1.md`, requiring all T001–T058 evidence, no critical/high security issue, and explicit confirmation that monitoring/reload/build execution remain deferred.
- [ ] T051 Synchronize Phase 1 completion/evidence to `.omx/plans/modern-apple-silicon-rewrite.md` and identify the next Spec Kit short name `reload-loop`.
- [ ] T052 [P] Audit every `Packages/LiveReloadCore/Sources/` and `Packages/LiveReloadCore/Tests/` import as part of `scripts/verify-modern.sh`; fail on `SwiftUI` or `AppKit`, and record the result in `docs/modernization/evidence/foundation/core-boundary-audit.md` (FR-005, FR-015).
- [ ] T053 [P] Generate and review the final package/project dependency inventory in `scripts/verify-modern.sh`; fail if a third-party package, CocoaPods, Node.js, Ruby, or CoffeeScript runtime is introduced, and record the sanitized result in `docs/modernization/evidence/foundation/dependency-final-audit.md` (FR-003, FR-015, SC-002).
- [ ] T054 [P] Establish the modern target's single version-source configuration and About/build metadata linkage; validate it against `VERSIONING.md` and add the Phase 1 `Unreleased` changelog workflow to `CHANGELOG.md` (FR-017).
- [ ] T055 [P] Reconcile `docs/project-ledger/software-inclusions.md` with Xcode/package manifests, source headers, generated artefacts, assets, build tools, and services; open ledger issues for every unknown inclusion and update `NOTICE.md` where attribution requires it (FR-018–FR-019).
- [ ] T056 [P] Update `docs/guides/user-guide.md` and `docs/guides/developer-guide.md` with verified Phase 1 setup, project lifecycle, recovery, accessibility, test, and limitation guidance; retain deferred features as explicitly unsupported (FR-020).
- [ ] T057 Add version/changelog, inclusion-register, NOTICE, and guide checks to `scripts/verify-modern.sh`; fail the Phase 1 release verification when required review/evidence is absent and capture results in `docs/modernization/evidence/foundation/documentation-audit.md` (FR-017–FR-020, SC-008).
- [ ] T058 Complete the Phase 1 documentation/release review in `docs/modernization/sprint-reviews/sprint-1.md`, linking version/changelog disposition, inclusion-register audit, NOTICE impact, guide updates, and any open provenance issue (SC-007, SC-008).

**Final checkpoint**: Phase 1 is complete only when T001–T058, all four story checkpoints, SC-001–SC-008, and the constitution gate pass. Phase 2 begins with a new `speckit.specify` flow; no Phase 2 production tasks are appended here.

---

## Dependencies and Execution Order

```text
Foundation/Governance (T001–T005)
  └─► Native baseline (T006–T014)
        └─► Shared models/contracts (T015–T022)
              ├─► US1 persistence/access (T023–T031)
              ├─► US4 diagnostics (T032–T035)
              └─► US3 accessible UI (T036–T043)
                    └─► Phase exit (T044–T058)
```

### Parallel opportunities

- T002–T004 and T007–T008 can proceed independently once T001/T006 establish their context.
- Model fixtures T015–T017 and model implementations T019–T020 can proceed in parallel where they write separate targets/files.
- After T021, persistence/access and diagnostics can proceed independently; UI implementation starts after their service contracts are stable.
- T044–T047 and T052–T056 can run in parallel after all story checkpoints pass; complete T048–T049, then T057–T058, before the final T050–T051 readiness/roadmap closeout.

## Traceability Summary

| User story | Requirements | Success criteria | Primary tasks |
|---|---|---|---|
| US1 Trusted project list | FR-004–FR-010, FR-015 | SC-003, SC-004 | T023–T031 |
| US2 Native baseline | FR-001–FR-003, FR-015–FR-016 | SC-001, SC-002 | T006–T014 |
| US3 Accessible management | FR-011–FR-012, FR-015 | SC-005 | T036–T043 |
| US4 Safe diagnostics | FR-013–FR-015 | SC-006 | T032–T035 |
| Phase exit | All | SC-001–SC-008 | T044–T058 |

## Notes

- Tests and fixtures precede production behavior where technically possible.
- `[P]` tasks still preserve unrelated workspace changes.
- A failed verification opens an issue and keeps the relevant checkpoint open; it is never converted to a checked task without evidence.
- Commit messages use the repository Lore Commit Protocol when commits are requested.
