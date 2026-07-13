# Tasks: Minimum Useful Reload Loop

**Input**: Design documents from `/specs/003-reload-loop/`

**Prerequisites**: [spec.md](./spec.md), [plan.md](./plan.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Tests and fixtures precede each production boundary. A task is complete only when its linked evidence exists and the applicable Debug/Release checks pass.

**Organization**: Tasks are grouped by independently testable user story. Shared foundations deliberately precede the first story that depends on them.

## Phase 1: Setup and Feature Test Surface

**Purpose**: Establish deterministic fixtures, test seams, and verification commands without enabling monitoring or browser serving.

- [x] T001 Create sanitized protocol-7, raw-frame, browser, monitor, exclusion, and recovery fixture directories under `tests/fixtures/reload-loop/`, reusing Phase 0 evidence by reference rather than copying legacy runtime code (FR-010, FR-014, FR-016).
- [x] T002 [P] Add a Phase 2 verification matrix and feature evidence index under `docs/modernization/evidence/reload-loop/` for core, integration, browser, UI, idle, privacy, and recovery gates (FR-016, SC-007).
- [x] T003 [P] Add failing core tests for bounded runtime event values, monitoring lifecycle state transitions, browser-session lifecycle, and reload decisions in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/` (FR-002–FR-004, FR-009–FR-014).
- [x] T004 [P] Add failing app-model and UI-test scenarios for stopped/starting/watching/recovering/failed monitoring, server readiness/port conflict, client count, and manual reload in `ModernLiveReload/LiveReloadAppTests/` and `ModernLiveReload/LiveReloadAppUITests/` (FR-001–FR-002, FR-015, FR-017, SC-006).

**Checkpoint**: Fixture and test seams exist; no production monitor, listener, or pipeline is active.

---

## Mandatory Pre-implementation Analysis Gate

**Purpose**: Prevent implementation from proceeding against an internally inconsistent Phase 2 contract.

- [x] T005 Run and record a strictly read-only cross-artifact analysis over the approved Phase 2 spec, plan, task ledger, constitution, ADRs, and design artifacts; resolve every critical/high finding before starting runtime contracts (SC-007).

**Checkpoint**: The implementation contract is internally consistent; critical/high analysis findings are resolved and recorded before T006 begins.

---

## Phase 2: Shared Runtime Contracts and Test Doubles

**Purpose**: Introduce bounded Sendable values and injectable boundaries that every story needs, while retaining Phase 1 persistence semantics.

- [x] T006 Define `MonitoringRuntimeState`, `MonitoringRecoveryReason`, `FileChangeSignal`, `ChangeBatch`, `ReloadDecision`, `ServerState`, and safe browser-session values in `Packages/LiveReloadCore/Sources/LiveReloadCore/Models/`; keep runtime state out of `ProjectStore` persistence (FR-002–FR-004, FR-011–FR-016).
- [x] T007 Define `FileEventSource`, `FileEventStream`, `ReloadServerControlling`, and injectable clock/test-double contracts in `Packages/LiveReloadCore/Sources/LiveReloadCore/Monitoring/` and `ReloadServer/` (FR-003–FR-004, FR-009–FR-014).
- [x] T008 Implement fake event source, fake reload server, fake browser session, and deterministic clock test support in `Packages/LiveReloadCore/Sources/LiveReloadCore/` and cover them in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/` (FR-003–FR-004, FR-011, FR-014).
- [x] T009 Verify model decoding, current configuration envelopes, and Phase 1 bookmark/project-store tests remain compatible after the new runtime contracts are introduced (FR-005, FR-016).

**Checkpoint**: Phase 2 services can be tested without SwiftUI, real FSEvents, sockets, or elapsed-time sleeps.

---

## Phase 3: User Story 2 — Start and Trust Project Monitoring (Priority: P1)

**Goal**: Let the user explicitly start and stop one project monitor with accurate visible state and preserved configuration.

**Independent Test**: Start/stop a disposable enabled project through the app model; fake and workspace-backed sources prove lifecycle idempotency, supported signals, folder-loss handling, and no reload after stop.

### Tests and monitoring state first

- [x] T010 [US2] Add failing lifecycle tests for start, stop, repeated start/stop, source failure, root change, event loss, folder loss, scope release, and pending-work cancellation in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/MonitoringTests.swift` (FR-001–FR-005, SC-002).
- [x] T011 [US2] Add a workspace-backed disposable-directory integration test for create/modify/rename/delete events and a root-change/recovery fixture in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/` (FR-003, SC-002).

### Implementation

- [x] T012 [US2] Implement the actor-owned `ProjectMonitor` lifecycle and explicit recovery transitions in `Packages/LiveReloadCore/Sources/LiveReloadCore/Monitoring/` (FR-001–FR-005).
- [x] T013 [US2] Implement the narrow direct-FSEvents adapter that copies callback paths/flags into bounded Sendable signals and maps required-scan/dropped/root-change conditions to recovery in `Packages/LiveReloadCore/Sources/LiveReloadCore/Monitoring/` (FR-003–FR-004).
- [x] T014 [US2] Extend `AppModel` composition and runtime projection for explicit per-project start/stop/retry actions without changing Phase 1 persistence ownership in `ModernLiveReload/LiveReloadApp/AppModel.swift` (FR-001–FR-005).
- [ ] T015 [US2] Add accessible stopped/starting/watching/recovering/failed views, controls, safe recovery copy, and identifiers in `ModernLiveReload/LiveReloadApp/Views/` (FR-002, FR-015, SC-006).
- [ ] T016 [US2] Complete app-model/UI regression tests for user start/stop and folder/stream recovery states in `ModernLiveReload/LiveReloadAppTests/` and `ModernLiveReload/LiveReloadAppUITests/` (FR-001–FR-005, SC-006).

**Checkpoint**: US2 passes its lifecycle and UI acceptance tests; the UI never claims watching after source, access, or recovery failure.

---

## Phase 4: User Story 3 — Control Noisy File Changes (Priority: P2)

**Goal**: Convert only meaningful project-relative changes into one deterministic settled batch.

**Independent Test**: Feed a fake source with mixed default-excluded, user-excluded, hidden, Unicode, symlink-escape, repeated, and 10,000-event inputs; inspect the resulting batches without launching the app.

### Tests and policy first

- [x] T017 [US3] Add failing ignore-rule tests covering default paths, user glob grammar, precedence, hidden files, Unicode normalization, relative-root escape, symlinks, and invalid patterns in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/IgnoreRuleTests.swift` (FR-006–FR-007).
- [x] T018 [US3] Add failing fake-clock batching tests for ordering, de-duplication, 100–500 ms settling, stop/recovery cancellation, and a 10,000-event burst in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/MonitoringTests.swift` (FR-008, FR-016, SC-003).

### Implementation

- [x] T019 [US3] Implement normalized project-relative path handling, built-in exclusions, positive user glob rules, and bounded safe summaries in `Packages/LiveReloadCore/Sources/LiveReloadCore/Monitoring/` (FR-006–FR-007, FR-016).
- [x] T020 [US3] Implement actor-owned `ChangeBatcher` with injected clock, one pending batch per project, ordered de-duplication, and cancellation in `Packages/LiveReloadCore/Sources/LiveReloadCore/Pipeline/` (FR-008, FR-016).
- [ ] T021 [US3] Surface safe settled-batch activity rows and verify long/path-overflow behavior in `ModernLiveReload/LiveReloadApp/Views/` and `ModernLiveReload/LiveReloadAppUITests/` (FR-016, SC-006).

**Checkpoint**: US3 passes mixed-burst and 10,000-event tests; excluded-only changes make no reload decision.

---

## Phase 5: User Story 1 — Automatically Refresh a Connected Browser (Priority: P1)

**Goal**: Serve compatible local browser clients and connect settled change batches to exactly one safe reload request.

**Independent Test**: Run raw-frame and Safari/Chromium fixtures against a disposable local server; verify negotiation, multiple clients, stylesheet/full-page classification, manual reload, and no reload from excluded or stopped projects.

### Protocol and server tests first

- [x] T022 [US1] Add protocol-7 golden tests for hello negotiation, reload encoding, defaults, unsupported commands, malformed JSON, and bounded values in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/ReloadProtocolTests.swift` using `tests/fixtures/reload-loop/protocol/` (FR-010, FR-012–FR-014).
- [x] T023 [US1] Add raw RFC-6455 integration tests for loopback bind, endpoint rejection, masked frames, frame/message limits, ping/pong, close, multiple clients, disconnect cleanup, restart, and port conflict in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/ReloadServerTests.swift` (FR-009–FR-011, FR-014–FR-016, SC-004).
- [x] T024 [US1] Add failing project-pipeline tests for stylesheet-only, full-page, manual, excluded-only, stopped, recovering, no-client, and multi-client reload decisions in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/ProjectPipelineTests.swift` (FR-012–FR-013, FR-017, SC-001).

### Implementation

- [x] T025 [US1] Implement typed protocol-7 message validation/encoding and bounded RFC-6455 frame parsing in `Packages/LiveReloadCore/Sources/LiveReloadCore/ReloadProtocol/` (FR-010, FR-014, FR-016).
- [x] T026 [US1] Implement actor-owned loopback `ReloadServer` on Darwin BSD sockets (not `Network.framework`) and isolated browser sessions in `Packages/LiveReloadCore/Sources/LiveReloadCore/ReloadServer/` (FR-009–FR-011, FR-014–FR-016).
- [x] T027 [US1] Implement `ProjectPipeline` to connect monitor batches and manual reload to one classified broadcast, with recovery/stopped/no-client suppression in `Packages/LiveReloadCore/Sources/LiveReloadCore/Pipeline/` (FR-008, FR-012–FR-013, FR-017).
- [x] T028 [US1] Compose server and per-project pipelines in `ModernLiveReload/LiveReloadApp/AppModel.swift`, expose safe connection count/manual reload state, and preserve existing project mutation gating (FR-011, FR-015, FR-017).
- [ ] T029 [US1] Add accessible local-server/no-client/client-count/manual-reload UI and identifiers in `ModernLiveReload/LiveReloadApp/Views/` with corresponding app/UI tests (FR-011, FR-015, FR-017, SC-006).
- [ ] T030 [US1] Run the existing Safari and Chromium browser fixtures against the production server and capture sanitized compatibility evidence in `docs/modernization/evidence/reload-loop/` (FR-010–FR-013, SC-001, SC-004, SC-007).

**Checkpoint**: US1 passes raw-server and browser-fixture acceptance tests; a meaningful settled change produces exactly one appropriate reload per ready client.

---

## Phase 6: User Story 4 — Recover From Browser and Folder Failures (Priority: P2)

**Goal**: Make folder, stream, listener, and client failures safe, visible, and isolated.

**Independent Test**: Trigger every failure through fakes or disposable integrations and verify preserved project configuration, accurate UI state, safe diagnostics, and unaffected sibling projects/clients.

- [ ] T031 [US4] Add failing integration regressions for unavailable/stale access, root removal, event loss, port conflict, malformed/oversized client, disconnect during broadcast, and server restart in `Packages/LiveReloadCore/Tests/LiveReloadCoreTests/` (FR-003–FR-005, FR-014–FR-016, SC-002, SC-004).
- [ ] T032 [US4] Implement recovery coordination, retry boundaries, client isolation, and safe activity mapping across `Packages/LiveReloadCore/Sources/LiveReloadCore/Monitoring/`, `ReloadServer/`, and `Pipeline/` (FR-003–FR-005, FR-014–FR-016).
- [ ] T033 [US4] Complete recovery UI, keyboard, VoiceOver, and UI-test coverage for monitor failure, repair, port conflict, retry, and preserved configuration in `ModernLiveReload/LiveReloadApp/` and `ModernLiveReload/LiveReloadAppUITests/` (FR-002, FR-015–FR-016, SC-006).

**Checkpoint**: US4 passes isolated-failure tests; no failure silently drops configuration or stops independent clients/projects.

---

## Phase 7: Performance, Verification, and Phase Exit

**Purpose**: Prove the complete reload loop, resource limits, privacy, documentation, and release posture before closing Phase 2.

- [ ] T034 [P] Add and run a five-minute idle CPU/resource sample after a 30-second warm-up, recording one process CPU sample per second plus the mean and peak, and repeated monitor/server start-stop cleanup evidence using a disposable workspace fixture; capture sanitized output in `docs/modernization/evidence/reload-loop/` (SC-005).
- [ ] T035 [P] Extend `scripts/verify-modern.sh` with Phase 2 core/integration/browser/fixture and privacy gates, ensuring it still rejects UI-framework leakage, third-party runtime dependencies, build products, and volatile agent metadata (FR-016, SC-007).
- [ ] T036 [P] Update `docs/guides/user-guide.md`, `docs/guides/developer-guide.md`, `CHANGELOG.md`, `docs/project-ledger/software-inclusions.md`, and `NOTICE.md` disposition for verified Phase 2 behavior and retained deferrals (FR-018, SC-007).
- [ ] T037 [P] Run the feature requirements checklist, full Debug/Release/unit/integration/UI/browser/privacy verification, and record evidence plus a constitution check in `docs/modernization/sprint-reviews/sprint-2.md` (SC-001–SC-007).
- [ ] T038 Update `docs/modernization/behavior-inventory.md`, relevant ADR links, issues, solutions, learnings, and the parent `.omx/plans/modern-apple-silicon-rewrite.md` with Phase 2 outcomes before handoff (FR-016, FR-018).
- [ ] T039 Run a strictly read-only cross-artifact analysis over the Phase 2 spec, plan, tasks, constitution, ADRs, and evidence; resolve critical/high findings under the implementation workflow before phase closure (SC-007).

**Final checkpoint**: Phase 2 is complete only when T001–T039, all four story checkpoints, SC-001–SC-007, the constitution gate, and Phase 2 evidence are complete. Phase 3 begins only through a fresh `speckit.specify` flow for `developer-workflow`.

---

## Dependencies and Execution Order

```text
Setup/test seams (T001–T004)
  └─► Pre-implementation analysis (T005)
        └─► Runtime contracts/fakes (T006–T009)
              └─► Monitoring lifecycle / US2 (T010–T016)
                    └─► Ignore + batching / US3 (T017–T021)
                          └─► Protocol, server, pipeline / US1 (T022–T030)
                                └─► Recovery hardening / US4 (T031–T033)
                                      └─► Performance, verification, phase exit (T034–T039)
```

### Parallel opportunities

- T001–T004 can proceed in parallel after fixture naming is agreed; T005 follows them and must pass before implementation.
- T006–T008 can proceed in parallel when they write distinct core subdirectories; T009 follows them.
- T010/T011 and T017/T018 are test-first lanes that can run in parallel after T008.
- T022–T024 are independent test-first lanes after runtime contracts; production T025–T027 then proceeds in dependency order.
- T034–T037 can run in parallel only after every story checkpoint passes; T038–T039 follow the final evidence.

## Traceability Summary

| User story | Requirements | Success criteria | Primary tasks |
|---|---|---|---|
| US1 Automatic browser refresh | FR-008–FR-014, FR-017 | SC-001, SC-004, SC-006, SC-007 | T022–T030 |
| US2 Trusted monitoring | FR-001–FR-005, FR-015–FR-016 | SC-002, SC-006 | T010–T016 |
| US3 Noise control | FR-006–FR-008, FR-016 | SC-003, SC-006 | T017–T021 |
| US4 Recovery | FR-002–FR-005, FR-014–FR-016 | SC-002, SC-004, SC-006 | T031–T033 |
| Phase exit | FR-016, FR-018 | SC-001–SC-007 | T034–T039 |

## Notes

- The first production monitor, server, parser, or pipeline change must be preceded by its corresponding failing test or fixture task.
- `[P]` marks work that may run in parallel when files and dependencies do not overlap.
- A failed verification keeps its task unchecked and is recorded as an issue; it is never converted to a completed task without new evidence.
- Commit messages use the repository Lore Commit Protocol when commits are requested.
