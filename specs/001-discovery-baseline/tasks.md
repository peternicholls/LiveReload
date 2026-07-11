---
description: "Dependency-ordered Phase 0 discovery baseline tasks"
---

# Tasks: Discovery Baseline

**Input**: Design documents from `/specs/001-discovery-baseline/`  
**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`  
**Roadmap mapping**: This file is canonical for Phase 0 execution. Parent-roadmap IDs are retained in task descriptions for cross-phase traceability.

## Format

- `[ ] TNNN [P?] [US?] Description with exact output path`
- **[P]**: safe to execute in parallel because it writes different files and has no unmet dependency.
- **[US1–US5]**: maps to the independently testable user stories in `spec.md`.
- `[x]` means completed with evidence, not merely attempted.

## Phase 1: Setup and Governance

**Purpose**: Establish the feature branch, governing artifacts, and durable tracking before research begins.

- [x] T001 Create and check out feature branch `001-discovery-baseline` and initialize `specs/001-discovery-baseline/`
- [x] T002 Complete and validate `specs/001-discovery-baseline/spec.md` against `specs/001-discovery-baseline/checklists/requirements.md`
- [x] T003 Complete constitution-gated technical design in `specs/001-discovery-baseline/plan.md`, `research.md`, `data-model.md`, `contracts/`, and `quickstart.md`
- [x] T004 [P] Ratify constitution v1.0.0 in `.specify/memory/constitution.md` (roadmap R-06.1)
- [x] T005 [P] Establish issue, solution, learning, ADR, and sprint-review templates under `docs/project-ledger/`, `docs/adr/`, and `docs/modernization/sprint-reviews/` (roadmap R-06.2–R-06.4)
- [ ] T006 Verify branch/status, record baseline `upstream/develop` SHA, and create an annotated private baseline tag as specified in `docs/modernization/behavior-inventory.md` metadata (roadmap R-01.1)
- [ ] T007 [P] Create Phase 0 artifact directories `Research/BrowserFixture/`, `Research/WebSocketPrototype/`, `Research/FSEventsPrototype/`, `Research/SigningPrototype/`, `tests/fixtures/livereload-protocol/`, and `docs/modernization/evidence/` with purpose README files matching `contracts/prototype-boundaries.md`
- [ ] T008 Run a ledger traceability dry run using a clearly marked temporary example in `docs/project-ledger/`, verify links/status rules, then remove the example and record the result in `docs/modernization/sprint-reviews/sprint-0.md` (roadmap R-06.5)

**Checkpoint**: Feature governance, directories, baseline identity, and evidence rules are ready. No research story begins before T006–T008 pass.

---

## Phase 2: User Story 1 — Understand Required Behavior (Priority: P1) 🎯 Foundation

**Goal**: Produce an evidence-backed inventory and reusable protocol fixtures that separate retained outcomes from obsolete mechanisms.

**Independent Test**: Select every `v1` record and trace it to source/observation evidence plus a future verification method; validate every protocol fixture against its expected interpretation.

### Evidence tests

- [ ] T009 [US1] Define and add the Behavior Record table/schema plus completeness validation procedure to `docs/modernization/behavior-inventory.md` before populating records
- [ ] T010 [P] [US1] Define fixture naming, sanitization, and expected-result format in `tests/fixtures/livereload-protocol/README.md`

### Research and artifacts

- [ ] T011 [P] [US1] Trace project lifecycle and persistence behavior in legacy source/tests and add cited `BEH-NNN` records to `docs/modernization/behavior-inventory.md` (roadmap R-01.2)
- [ ] T012 [P] [US1] Trace monitoring, ignore/filter, and change batching behavior in legacy source/tests and add cited behavior records to `docs/modernization/behavior-inventory.md` (roadmap R-01.2)
- [ ] T013 [P] [US1] Trace protocol handshake, reload classification, and client-connection behavior in legacy source/tests and add cited behavior records to `docs/modernization/behavior-inventory.md` (roadmap R-01.2)
- [ ] T014 [P] [US1] Trace build trigger, output, success/failure, and cancellation behavior in legacy source/tests and add cited behavior records to `docs/modernization/behavior-inventory.md` (roadmap R-01.2)
- [ ] T015 [US1] After static inspection and hash/signature capture, optionally attempt archived-app observation under Rosetta only in a disposable account/isolated environment with no private project mounts, no credentials, restricted networking, and explicit stop conditions; otherwise record the blocker and use source/tests as evidence in `docs/project-ledger/issues.md` and the inventory (roadmap R-01.3; depends on T011–T014)
- [ ] T016 [US1] Reconcile conflicts and classify every behavior `v1`, `deferred`, or `rejected` with future verification in `docs/modernization/behavior-inventory.md` (depends on T011–T015)
- [ ] T017 [US1] Add sanitized valid/invalid hello and reload payload fixtures plus expected results under `tests/fixtures/livereload-protocol/` (roadmap R-01.5; depends on T010, T013)
- [ ] T018 [US1] Run the inventory and fixture completeness procedures, record results in `docs/modernization/evidence/behavior-validation.md`, and open ledger issues for every gap

**Checkpoint**: US1 passes SC-001; all v1 behavior is evidence-backed and fixtures are reusable independently.

---

## Phase 3: User Story 2 — Prove Browser Interoperability (Priority: P1)

**Goal**: Establish current Safari and Chromium protocol expectations before server implementation.

**Independent Test**: Run the standalone browser fixture without the macOS app and reproduce each compatibility-matrix row.

### Fixture tests

- [ ] T019 [US2] Write the manual/automated browser observation procedure and matrix schema in `docs/modernization/browser-compatibility.md` before implementing the fixture
- [ ] T020 [P] [US2] Select maintained LiveReload client source/version from primary documentation and record provenance/licence evidence in `Research/BrowserFixture/README.md` (roadmap R-02.1)

### Research and artifacts

- [ ] T021 [US2] Implement minimal HTML/CSS/JavaScript pages plus a disposable loopback-only fixture endpoint in `Research/BrowserFixture/`; document its language/runtime, served routes, handshake/reload injection method, lifecycle, and why it is not the production server, using fixtures from T017 (roadmap R-02.2; depends on T017, T020)
- [ ] T022 [P] [US2] Execute and capture current Safari handshake, CSS reload, and page reload observations under `docs/modernization/evidence/browser/safari/` (roadmap R-02.3; depends on T019, T021)
- [ ] T023 [P] [US2] Execute and capture current Chromium handshake, CSS reload, and page reload observations under `docs/modernization/evidence/browser/chromium/` (roadmap R-02.3; depends on T019, T021)
- [ ] T024 [US2] Reconcile results into supported/partial/unsupported rows with exact versions and evidence in `docs/modernization/browser-compatibility.md` (roadmap R-02.4; depends on T022, T023)
- [ ] T025 [US2] Re-run the independent fixture from `specs/001-discovery-baseline/quickstart.md`, record reproducibility result, and open issues for discrepancies

**Checkpoint**: US2 passes SC-002 and provides the client-side contract for the WebSocket prototype.

---

## Phase 4: User Story 3 — Retire Architectural Unknowns (Priority: P1)

**Goal**: Prove WebSocket, FSEvents, and persistent folder-access boundaries with executable Apple-silicon prototypes and accepted decisions.

**Independent Test**: Build/run each prototype from its README, execute every required normal/error scenario, and reproduce ADR verification evidence.

### WebSocket tests first

- [ ] T026 [US3] Write failing/expected scenario tests for bind, protocol-7 handshake, reload, multiple clients, disconnect, malformed input, and port collision in `Research/WebSocketPrototype/Tests/` using T017/T024 fixtures
- [ ] T027 [P] [US3] Research installed Network.framework server-side WebSocket APIs from Apple documentation/SDK headers and record findings in `docs/project-ledger/learnings.md` with source/version (roadmap R-03.1)

### WebSocket prototype

- [ ] T028 [US3] Implement the smallest loopback-only Swift WebSocket command-line prototype in `Research/WebSocketPrototype/` that can satisfy T026 (roadmap R-03.2; depends on T026, T027)
- [ ] T029 [US3] Add bounded input/output, connection lifecycle, malformed-frame handling, and latency capture to `Research/WebSocketPrototype/` (depends on T028)
- [ ] T030 [US3] Execute T026 against the Safari/Chromium fixture, preserve results under `docs/modernization/evidence/websocket/`, and record limitations/issues (roadmap R-03.3; depends on T024, T029)
- [ ] T031 [US3] Write and accept `docs/adr/001-websocket-server.md` with drivers, alternatives, decision, consequences, fallback, and T030 evidence (roadmap R-03.4)

### FSEvents/bookmark tests first

- [ ] T032 [P] [US3] Write expected scenarios for create, modify, rename, delete, root change, dropped events, start/stop, and burst behavior in `Research/FSEventsPrototype/Tests/`
- [ ] T033 [P] [US3] Write expected bookmark scenarios for create, restore, balanced access, stale resolution, failure, and repair in `Research/FSEventsPrototype/Tests/`

### FSEvents/bookmark prototype

- [ ] T034 [US3] Implement FSEvents adapter prototype with immediate callback-data copying and typed Sendable events in `Research/FSEventsPrototype/` (roadmap R-04.1; depends on T032)
- [ ] T035 [P] [US3] Implement minimal AppKit bookmark selection/restoration/repair harness in `Research/FSEventsPrototype/` (roadmap R-04.3; depends on T033)
- [ ] T036 [US3] Exercise root rename/removal, dropped events, 10,000-event burst, inaccessible folder, and sleep/wake; save results under `docs/modernization/evidence/monitoring/` (roadmap R-04.2; depends on T034, T035)
- [ ] T037 [US3] Write and accept `docs/adr/002-monitoring-and-folder-access.md` with stream options, ownership, debounce boundary, bookmark lifecycle, rescan/recovery rules, alternatives, and T036 evidence (roadmap R-04.4)
- [ ] T038 [US3] Run both prototype READMEs from a clean build directory and record a combined reproducibility verdict in `docs/modernization/evidence/prototype-validation.md`

**Checkpoint**: US3 passes SC-003/SC-004/SC-005 for ADR-001/ADR-002. Any failed required scenario remains architecture-blocking.

---

## Phase 5: User Story 4 — Establish Durable Governance (Priority: P2)

**Goal**: Prove that the constitution and ledgers support real discovery work and preserve traceability.

**Independent Test**: Trace at least one genuine research problem from task to issue, evidence, resolution/decision/learning, and sprint disposition.

- [x] T039 [P] [US4] Create `.specify/memory/constitution.md` with versioned principles, quality gates, governance, amendments, and exception rules (roadmap R-06.1)
- [x] T040 [P] [US4] Create stable-ID issue, solution, and learning templates under `docs/project-ledger/` (roadmap R-06.2)
- [x] T041 [P] [US4] Create ADR and sprint-review templates under `docs/adr/` and `docs/modernization/sprint-reviews/` (roadmap R-06.3)
- [x] T042 [US4] Define task checkbox/evidence/status rules in `.omx/plans/modern-apple-silicon-rewrite.md` and verify unique parent-roadmap IDs (roadmap R-06.4–R-06.5)
- [ ] T043 [US4] Link at least one genuine Phase 0 issue, or the clearly marked controlled traceability exercise from T008 when no genuine issue exists, to its originating `TNNN`, evidence, solution/learning/ADR, and `docs/modernization/sprint-reviews/sprint-0.md`
- [ ] T044 [US4] Perform the post-execution constitution review, record compliance/exceptions in `docs/modernization/sprint-reviews/sprint-0.md`, and create issues for violations

**Checkpoint**: US4 passes SC-006/SC-007; project memory is demonstrated with real work rather than templates alone.

---

## Phase 6: User Story 5 — Define Private Distribution Constraints (Priority: P2)

**Goal**: Establish attribution, asset provenance, signing, hardened-runtime, sandbox, and public/private boundaries before production packaging decisions.

**Independent Test**: Review every conclusion against cited evidence, inspect the asset inventory, and reproduce the empty-app signing check.

- [ ] T045 [P] [US5] Confirm repository licence text, release history, and last official binary evidence from primary sources; record sourced facts in `docs/modernization/distribution-research.md` without unsupported legal conclusions (roadmap R-05.1)
- [ ] T046 [P] [US5] Inventory historical icons/images/frameworks into `docs/modernization/asset-provenance.md` using `AST-NNN` records and classify each `reusable`, `replace`, `excluded`, or `unknown` (roadmap R-05.2)
- [ ] T047 [P] [US5] Create `NOTICE.md` retaining required attribution and clearly distinguishing the modernization work
- [ ] T048 [US5] Build/sign a minimal arm64 hardened-runtime harness from `Research/SigningPrototype/`, inspect architecture/entitlements/signature, and save commands/results under `docs/modernization/evidence/signing/` (roadmap R-05.3; depends on T045)
- [ ] T049 [US5] Research App Sandbox implications for folder bookmarks, loopback networking, and child developer tools using Apple primary sources; record evidence/limits in `docs/modernization/distribution-research.md`
- [ ] T050 [US5] Write and accept `docs/adr/003-distribution-security.md` covering private preview, signing, hardened runtime, sandbox status, public-distribution boundary, assets, risks, and T045–T049 evidence (roadmap R-05.4)

**Checkpoint**: US5 passes SC-005 for ADR-003 and SC-008; no unknown asset enters the modern release path.

---

## Phase 7: Cross-Artifact Validation and Phase Exit

**Purpose**: Prove the entire Phase 0 artifact set is internally consistent and ready to hand off.

- [ ] T051 [P] Validate all `BEH`, `FXT`, `OBS`, `ADR`, `ISS`, `SOL`, `LRN`, and `AST` IDs for uniqueness and required fields; save the check/result in `docs/modernization/evidence/artifact-validation.md`
- [ ] T052 [P] Search new artifacts for credentials, tokens, personal absolute paths, private source contents, unclassified assets, and committed build products; record sanitized result in `docs/modernization/evidence/privacy-review.md`
- [ ] T053 Build every Swift research target in Debug and Release with warnings treated as errors, run all prototype/fixture tests from clean build directories, and record exact commands/results in `docs/modernization/sprint-reviews/sprint-0.md`
- [ ] T054 Revalidate `specs/001-discovery-baseline/checklists/requirements.md` against completed artifacts and correct any regression
- [ ] T055 Run Spec Kit cross-artifact analysis over `spec.md`, `plan.md`, `tasks.md`, constitution, ADRs, and research artifacts; resolve every critical/high finding
- [ ] T056 Complete the Phase Readiness Verdict in `docs/modernization/sprint-reviews/sprint-0.md`, requiring zero open architecture-blocking issues and accepted ADR-001/002/003
- [ ] T057 Update `.omx/plans/modern-apple-silicon-rewrite.md` Phase 0 checkboxes from this canonical task evidence and identify the next phase's new Spec Kit feature short name

**Final checkpoint**: Phase 0 is complete only when T001–T057, all story checkpoints, SC-001–SC-009, and the constitution gate pass. Phase 1 begins with a new `speckit.specify` flow, not by appending production tasks here.

---

## Dependencies and Execution Order

### Phase dependencies

```text
Setup/Governance (T001–T008)
   └─► US1 Behavior (T009–T018)
          └─► US2 Browser (T019–T025)
                 └─► US3 WebSocket path (T026–T031)
US1 ─────────────────► US3 FSEvents path (T032–T038)
Setup ───────────────► US4 Governance proof (T039–T044)
Setup ───────────────► US5 Distribution (T045–T050)
US1–US5 ─────────────► Exit validation (T051–T057)
```

### Parallel opportunities

- T011–T014 may run in parallel after T009/T010.
- Safari T022 and Chromium T023 may run in parallel after T021.
- WebSocket API research T027 and FSEvents/bookmark scenario design T032/T033 may run in parallel after browser expectations are stable enough for T026.
- FSEvents T034 and bookmark harness T035 may run in parallel.
- US5 evidence tasks T045–T047 may run in parallel; T049 can proceed alongside signing T048.
- US4 proof can proceed as soon as a genuine issue arises in any research story.

## Traceability Summary

| User story | Requirements | Success criteria | Primary tasks |
|---|---|---|---|
| US1 Required behavior | FR-001–FR-003, FR-016 | SC-001 | T009–T018 |
| US2 Browser interoperability | FR-004–FR-005 | SC-002 | T019–T025 |
| US3 Architecture unknowns | FR-006–FR-010, FR-017–FR-018 | SC-003–SC-005, SC-009 | T026–T038 |
| US4 Durable governance | FR-013–FR-015 | SC-006–SC-007 | T039–T044 |
| US5 Distribution constraints | FR-011–FR-012 | SC-005, SC-008 | T045–T050 |
| Phase exit | All | SC-001–SC-009 | T051–T057 |

## Execution Strategy

1. Finish shared setup and baseline identity.
2. Complete US1 and US2 before locking the WebSocket decision.
3. Run WebSocket and monitoring prototype lanes independently where dependencies allow.
4. Capture genuine governance traceability during research, not retrospectively.
5. Complete distribution research before Phase 1 build configuration is specified.
6. Stop for cross-artifact analysis and readiness verdict; do not implement the production app on this branch.

## Notes

- Tests/scenario definitions precede prototype implementation where technically possible.
- `[P]` tasks must still preserve unrelated user changes in the shared working tree.
- Use primary documentation for current API facts and record version-sensitive evidence.
- A failed prototype scenario opens an issue and keeps the relevant ADR proposed; it is not silently converted into success.
- Commit using the repository's Lore Commit Protocol when commits are requested.
