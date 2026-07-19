# Tasks: Developer Workflow and Daily Usability

**Input**: Design documents from `/specs/004-developer-workflow/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and `quickstart.md`

**Tests**: Included because the specification requires fixture, lifecycle, UI, accessibility, performance, and release evidence.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish fixtures, paths, and documentation surfaces without changing runtime behavior.

- [ ] T001 [P] Add the deterministic `LiveReloadBuildFixture` Swift executable target and scenarios for success, nonzero exit, timeout, run-only cancellation, oversized output, and a spawned descendant in `Packages/LiveReloadCore/Package.swift`, `Packages/LiveReloadCore/Sources/LiveReloadBuildFixture/main.swift`, and `tests/fixtures/developer-workflow/builds/scenarios.json`.
- [ ] T002 [P] Add configuration migration and invalid-value fixtures in `tests/fixtures/developer-workflow/configuration/`.
- [ ] T003 [P] Add lifecycle stress scenarios for active-build events, ordinary and lifecycle cancellation, removal, sleep/wake, network/path transitions, and duplicate-resource detection in `tests/fixtures/developer-workflow/lifecycle/scenarios.json`.
- [ ] T004 Record the Phase 3 issue, solution, and learning placeholders and link the feature branch in `docs/project-ledger/issues.md`, `docs/project-ledger/solutions.md`, and `docs/project-ledger/learnings.md`.

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Define shared value types, persistence invariants, bounded diagnostics, and test seams before user-story work.

- [ ] T005 [P] Replace and move the existing placeholder `BuildConfiguration` from `Packages/LiveReloadCore/Sources/LiveReloadCore/Models/ProjectConfiguration.swift` into `Packages/LiveReloadCore/Sources/LiveReloadCore/Process/BuildConfiguration.swift`, preserving decoding compatibility while adding the specified path, timeout, argument, environment, and project-root validation.
- [ ] T006 [P] Define `BuildRun`, terminal result classifications, 1 MiB live-output/16 KiB line/4 KiB summary bounds, and file-change-only `BuildBatch` in `Packages/LiveReloadCore/Sources/LiveReloadCore/Models/RuntimeModels.swift`.
- [ ] T007 [P] Add injectable process clock, termination grace period, output-cap test seams, and a narrow process-group control adapter for direct/descendant teardown in `Packages/LiveReloadCore/Sources/LiveReloadCore/Process/BuildRunnerSupport.swift`.
- [ ] T008 Extend the versioned envelope with known-field migration defaults, future-schema write protection, and global settings persistence without promising unknown-key round-trip in `Packages/LiveReloadCore/Sources/LiveReloadCore/Models/ConfigurationEnvelope.swift` and `Packages/LiveReloadCore/Sources/LiveReloadCore/Persistence/ProjectStore.swift`.
- [ ] T009 Add bounded/redacted activity events and recovery summaries for build results in `Packages/LiveReloadCore/Sources/LiveReloadCore/Diagnostics/ActivityStore.swift`.
- [ ] T010 Add foundational persistence, known-field migration, future-schema protection, numeric-bound, project-root containment, executable replacement/revalidation, and redaction regression tests in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/BuildConfigurationTests.swift` and `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/RuntimePersistenceCompatibilityTests.swift`.

**Checkpoint**: Foundational value, persistence, and diagnostic contracts are stable; user stories can proceed in priority order.

## Phase 3: User Story 1 - Configure a Safe Project Build (Priority: P1) 🎯 MVP

**Goal**: Users can create, validate, persist, restore, and review a structured build configuration without a shell command.

**Independent Test**: Configure a disposable fixture, restart, verify round-trip and redaction, then submit invalid executable, directory, timeout, and environment values and verify prior-value preservation.

### Tests for User Story 1

- [ ] T011 [P] [US1] Add fixture-driven valid/invalid configuration contract tests covering missing/non-executable and legitimate in-place executable replacement, symlink escape, NUL rejection, argument/environment/timeout bounds, the exact reserved-key deny-list, allowed `PATH`, and prior-value preservation in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/BuildConfigurationTests.swift`.
- [ ] T012 [P] [US1] Add app-model persistence, prior-value preservation, and redacted-summary tests proving argument/environment values are absent while safe labels, counts, keys, timeout, and state remain in `ModernLiveReload/LiveReloadAppTests/LiveReloadAppTests.swift`.

### Implementation for User Story 1

- [ ] T013 [US1] Implement structured configuration validation and migration integration in `Packages/LiveReloadCore/Sources/LiveReloadCore/Process/BuildConfiguration.swift` and `Packages/LiveReloadCore/Sources/LiveReloadCore/Persistence/ProjectStore.swift`.
- [ ] T014 [US1] Add project build editor state, field validation, and a summary projection limited to executable label, project-relative working directory, argument count, environment-key names, timeout, and enabled state in `ModernLiveReload/LiveReloadApp/AppModel.swift`.
- [ ] T015 [US1] Add executable picker, argument list, working-directory picker, environment editor, timeout validation, and save/cancel states in `ModernLiveReload/LiveReloadApp/Views/BuildConfigurationViews.swift`.
- [ ] T016 [US1] Add accessibility labels, UI-test identifiers, and invalid-save recovery presentation for the build editor in `ModernLiveReload/LiveReloadApp/Views/BuildConfigurationViews.swift`.

**Checkpoint**: US1 independently passes persistence, validation, redaction, and accessible editor tests.

## Phase 4: User Story 2 - Build Before Reload Predictably (Priority: P1)

**Goal**: A configured project runs one owned build before reload, reports bounded results, coalesces active-build changes, and suppresses reload on every unsuccessful result.

**Independent Test**: Run fixture success, launch-failure, nonzero, timeout, cancellation, and oversized-output scenarios plus a 10,000-event burst; verify classifications, no overlap/orphans, coalescing, and no-build compatibility.

### Tests for User Story 2

- [ ] T017 [P] [US2] Add fixture-driven success, launch-failure, nonzero, timeout, run-only/lifecycle cancellation, exact truncation, 2-second graceful-escalation, and direct/descendant orphan-process tests in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/BuildRunnerTests.swift`.
- [ ] T018 [P] [US2] Add build/reload ordering, ordinary-terminal follow-up, lifecycle-discard, failure-suppression, no-build compatibility, and **Reload Now** bypass/non-mutation regression tests in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/ProjectPipelineTests.swift`.
- [ ] T019 [P] [US2] Add the deterministic 10,000-event stress scenario plus overlap, one-follow-up, lifecycle-discard, truncation, and 5 MiB logical diagnostic-payload assertions in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/BuildPipelineStressTests.swift`.

### Implementation for User Story 2

- [ ] T020 [US2] Implement actor-owned `BuildRunner` around `Process`, `Pipe`, and the process-group adapter with incremental output bounded to the specified byte/line/summary caps in `Packages/LiveReloadCore/Sources/LiveReloadCore/Process/BuildRunner.swift`.
- [ ] T021 [US2] Implement graceful process-group cancellation with a 2-second maximum before forced termination, timeout classification, descendant teardown ownership, and idempotent terminal publication in `Packages/LiveReloadCore/Sources/LiveReloadCore/Process/BuildRunner.swift`.
- [ ] T022 [US2] Extend `ProjectPipeline` with build gating, the one-active-run invariant, ordinary-terminal follow-up, lifecycle pending-batch discard, failure suppression, and immediate non-mutating **Reload Now** behavior in `Packages/LiveReloadCore/Sources/LiveReloadCore/Pipeline/ProjectPipeline.swift`.
- [ ] T023 [US2] Add queued/running/succeeded/failed/cancelled/timed-out activity projections, output views, and a keyboard-accessible **Cancel Current Build** action shown only for an active run in `ModernLiveReload/LiveReloadApp/Views/ProjectRuntimeViews.swift`.
- [ ] T024 [US2] Wire build-run updates, run-only/lifecycle cancellation reasons, project removal, app termination, and manual bypass through the runtime service in `ModernLiveReload/LiveReloadApp/Services/ReloadLoopRuntimeService.swift`.
- [ ] T025 [US2] Add build result, queued, failed-state, and active-run cancellation presentation/mutation gates in `ModernLiveReload/LiveReloadApp/AppModel.swift`.

**Checkpoint**: US2 passes all fixture/process/pipeline tests and preserves Phase 2 no-build reload behavior.

## Phase 5: User Story 3 - Control the App from the Menu Bar (Priority: P2)

**Goal**: The essential health and project controls work from a menu-bar surface with the main window closed.

**Independent Test**: Close the main window, operate health, pause/resume, **Reload Now**, open-window, and quit commands by keyboard and VoiceOver, and compare state with the main-window route.

### Tests for User Story 3

- [ ] T026 [P] [US3] Add shared command-routing tests for menu and window actions, including **Reload Now** labelling, immediate broadcast, and active/pending build non-mutation, in `ModernLiveReload/LiveReloadAppTests/LiveReloadAppTests.swift`.
- [ ] T027 [P] [US3] Add menu-bar health, keyboard, VoiceOver, non-color-only, and closed-window UI tests in `ModernLiveReload/LiveReloadAppUITests/LiveReloadAppUITests.swift`.

### Implementation for User Story 3

- [ ] T028 [US3] Define shared app command routing and menu-bar status projection in `ModernLiveReload/LiveReloadApp/AppModel.swift`.
- [ ] T029 [US3] Implement menu-bar health, active-project, browser-count, pause/resume, explicitly labelled **Reload Now** bypass, open-window, and quit views in `ModernLiveReload/LiveReloadApp/Views/MenuBarViews.swift` and `ModernLiveReload/LiveReloadApp/LiveReloadApp.swift`.
- [ ] T030 [US3] Add keyboard equivalents, VoiceOver labels, UI-test identifiers, reduced-motion behavior, and non-color-only status cues in `ModernLiveReload/LiveReloadApp/Views/MenuBarViews.swift`.

**Checkpoint**: US3 is independently operable with the main window closed and shares mutation behavior with the main-window route.

## Phase 6: User Story 4 - Configure Defaults and Exclusions (Priority: P2)

**Goal**: Users can safely configure global defaults and per-project ignore rules with preview, reset, migration, and validation.

**Independent Test**: Change every setting, restart, preview relative paths, reset, and load migration fixtures; verify validation and non-destructive behavior.

### Tests for User Story 4

- [ ] T031 [P] [US4] Add exact port/debounce/history defaults and bounds, immediate newest-event retention after history reduction, empty custom-global-exclusion default, `showMainWindow`/`menuBarOnly` presentation-only behavior, known-field migration, non-destructive reset, and persistence tests in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/SettingsTests.swift`.
- [ ] T032 [P] [US4] Add fixed/global/project exclusion-layer preview and precedence, reset preservation, hidden/Unicode/nested path, and redaction UI tests in `ModernLiveReload/LiveReloadAppUITests/LiveReloadAppUITests.swift`.

### Implementation for User Story 4

- [ ] T033 [US4] Implement the validated global settings model, exact defaults/bounds, presentation-only launch behavior, and known-field migration in `Packages/LiveReloadCore/Sources/LiveReloadCore/Models/Settings.swift`, `Packages/LiveReloadCore/Sources/LiveReloadCore/Models/ConfigurationEnvelope.swift`, and `Packages/LiveReloadCore/Sources/LiveReloadCore/Persistence/ProjectStore.swift`.
- [ ] T034 [US4] Implement settings and per-project exclusion editors with match preview and reset actions in `ModernLiveReload/LiveReloadApp/Views/SettingsViews.swift`.
- [ ] T035 [US4] Add bounded activity-history reconfiguration in `Packages/LiveReloadCore/Sources/LiveReloadCore/Diagnostics/ActivityStore.swift` and wire port, debounce, history, exclusion, and launch-presentation changes through `ModernLiveReload/LiveReloadApp/AppModel.swift` and `ModernLiveReload/LiveReloadApp/Services/ReloadLoopRuntimeService.swift` without restarting unrelated projects.

**Checkpoint**: US4 independently passes settings, migration, ignore preview, reset, and accessibility tests.

## Phase 7: User Story 5 - Recover from Expected Failures (Priority: P2)

**Goal**: Folder, port, lifecycle, and build failures preserve configuration and expose direct recovery actions without duplicate resources.

**Independent Test**: Inject each failure while multiple projects are active; verify only the affected work stops, configuration remains, and retry/repair leaves one owner per resource.

### Tests for User Story 5

- [ ] T036 [P] [US5] Add folder-loss, occupied-port, sleep/wake, network/path-transition, build-failure, lifecycle pending-discard, and project-removal tests in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/RecoveryLifecycleTests.swift`.
- [ ] T037 [P] [US5] Add injected-error recovery, repeated-click, redaction, and unrelated-project isolation UI tests in `ModernLiveReload/LiveReloadAppUITests/LiveReloadAppUITests.swift`.

### Implementation for User Story 5

- [ ] T038 [US5] Implement recovery coordinator state and idempotent retry/repair/correction actions in `Packages/LiveReloadCore/Sources/LiveReloadCore/Pipeline/ProjectPipeline.swift`.
- [ ] T039 [US5] Add folder, server, process, and lifecycle recovery projections with actionable summaries in `ModernLiveReload/LiveReloadApp/AppModel.swift` and `ModernLiveReload/LiveReloadApp/Views/RecoveryViews.swift`.
- [ ] T040 [US5] Handle sleep/wake, network/path transitions, project removal, and app termination without duplicate monitors, listeners, process groups, or pending builds in `ModernLiveReload/LiveReloadApp/Services/ReloadLoopRuntimeService.swift`.

**Checkpoint**: US5 passes injected and real lifecycle tests, preserving unrelated projects and resource ownership.

## Phase 8: Polish and Cross-Cutting Concerns

**Purpose**: Capture evidence, update durable project memory and guides, and close the Phase 3 gate.

- [ ] T041 [P] Add sanitized Phase 3 build, build-to-browser, process-group teardown, pipeline, menu, settings, recovery, truncation, logical-memory-budget, and idle-resource evidence under `docs/modernization/evidence/developer-workflow/`.
- [ ] T042 [P] Update `docs/guides/user-guide.md` and `docs/guides/developer-guide.md` for structured builds, bounded diagnostics, menu-bar controls, settings, and recovery.
- [ ] T043 [P] Update `docs/project-ledger/issues.md`, `docs/project-ledger/solutions.md`, `docs/project-ledger/learnings.md`, and `docs/project-ledger/software-inclusions.md` with linked task/test/decision evidence.
- [ ] T044 [P] Review and update `CHANGELOG.md`, `NOTICE.md`, and `docs/modernization/behavior-inventory.md` for accepted Phase 3 behavior and any inclusion/attribution impact.
- [ ] T045 Extend `scripts/verify-modern.sh` to validate every `tests/fixtures/developer-workflow/` group, Phase 3 evidence/privacy patterns, build-to-browser results, process-group cleanup, numeric truncation/memory caps, updated documentation, and an opt-in live `RUN_DEVELOPER_WORKFLOW_GATE=1` path rather than relying on the existing Phase 2-only fixture/evidence checks.
- [ ] T046 Run the focused package/app commands, the opt-in developer-workflow gate, `scripts/verify-reload-idle.sh`, the supported five-minute idle/resource gate, and the full `scripts/verify-modern.sh`; resolve all warnings, test failures, orphan processes, privacy findings, performance/bound misses, and documentation consistency errors.
- [ ] T047 Record the Phase 3 sprint review, link T001–T047 evidence, and synchronize the parent roadmap phase status in `docs/modernization/sprint-reviews/sprint-3.md` and `.omx/plans/modern-apple-silicon-rewrite.md`.

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No implementation dependency; fixtures and ledger surfaces can start immediately.
- **Foundational (Phase 2)**: Depends on Setup; blocks all user stories because persistence, bounded diagnostics, and value contracts are shared.
- **US1 (Phase 3)**: Depends on Foundational; MVP for configuring a safe build.
- **US2 (Phase 4)**: Depends on Foundational and the persisted configuration contract from US1; no-build behavior remains independently testable.
- **US3 (Phase 5)**: Depends on Foundational and app command projections from US2; can be developed in parallel with US4 after shared app routing is stable.
- **US4 (Phase 6)**: Depends on Foundational; can be developed in parallel with US3, then wired into runtime services.
- **US5 (Phase 7)**: Depends on US2's lifecycle ownership and US3/US4's recovery/settings surfaces.
- **Polish (Phase 8)**: Depends on all desired stories and their evidence; T045 extends the gate before T046 runs it, and T047 closes the phase only after T046 passes.

### User Story Dependencies

- **US1**: Foundational only; first implementation slice and MVP.
- **US2**: Foundational + US1 persistence/configuration; required for build-gated reload.
- **US3**: Foundational + shared app model; integrates US2 state but has independent menu tests.
- **US4**: Foundational + existing exclusion service; independent of menu presentation.
- **US5**: US2 lifecycle and the recovery presentation surfaces from US3/US4.

### Parallel Opportunities

- T001–T003 and T005–T007 can run in parallel because they touch separate fixture/value files.
- T011–T012, T017–T019, T026–T027, T031–T032, and T036–T037 are parallel test-writing lanes before their story implementations.
- After Foundational, US3 and US4 can proceed in parallel if app-model file conflicts are coordinated.
- T041–T044 are parallel documentation/evidence lanes after implementation stabilizes; T045–T047 are sequential.

## Parallel Example: User Story 2

```text
Task T017: BuildRunner result and orphan-process tests
Task T018: ProjectPipeline ordering and reload-suppression tests
Task T019: 10,000-event stress test
```

These tests can be written together and should fail against the current no-build pipeline before T020–T022 implement the behavior.

## Implementation Strategy

### MVP first

1. Complete Setup and Foundational phases.
2. Complete US1 and verify structured configuration round-trip and validation.
3. Complete US2 and verify success/failure gating plus no-build compatibility.
4. Stop at the US2 checkpoint for the first demonstrable Phase 3 value increment.

### Incremental delivery

1. Add menu-bar control (US3) without duplicating command routing.
2. Add settings/exclusions (US4) with migration and preview evidence.
3. Add recovery/lifecycle hardening (US5) and run the sprint exit gate.
4. Close documentation, ledger, inclusion, version, and roadmap artifacts only with linked evidence.

### Notes

- Every task has a checkbox, stable ID, required story label in story phases, and an exact repository path.
- Tests are written before implementation where practical, and checked tasks require evidence rather than code presence alone.
- Do not add compiler presets, shell mode, or launch-at-login implementation under this ledger; re-plan them as a later feature.
