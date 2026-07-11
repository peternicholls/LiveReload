# Feature Specification: Discovery Baseline

**Feature Branch**: `001-discovery-baseline`

**Created**: 2026-07-11

**Status**: Ready for research

**Input**: Phase 0 discovery and decision baseline for the modern Apple-silicon LiveReload rewrite.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Understand Required Behavior (Priority: P1)

As the rewrite maintainer, I need an evidence-backed inventory of the original application's observable behavior so that the modern product preserves useful outcomes without inheriting obsolete implementation choices.

**Why this priority**: Every subsequent specification depends on knowing which behaviors are required, deferred, rejected, or still uncertain.

**Independent Test**: Review the inventory against the legacy source, tests, and any executable observations; select any v1 behavior and trace it to evidence, scope classification, and a future verification method.

**Acceptance Scenarios**:

1. **Given** an observable legacy behavior, **When** it is entered in the inventory, **Then** it has a source or observation reference, a `v1`, `deferred`, or `rejected` classification, and a stated verification method.
2. **Given** a legacy behavior that depends on an obsolete runtime, **When** it is classified for v1, **Then** the retained outcome is separated from the obsolete mechanism.
3. **Given** the original application cannot run safely on the current Mac, **When** runtime observation is attempted, **Then** the blocker is recorded and source/tests are used as explicitly labelled evidence rather than guessed behavior.

---

### User Story 2 - Prove Browser Interoperability (Priority: P1)

As a future LiveReload user, I need evidence that current browsers can negotiate the standard protocol and respond to reload messages so that the rewrite does not require a bespoke browser extension.

**Why this priority**: Browser interoperability is the central product value and a hard dependency for the minimum useful loop.

**Independent Test**: Run a standalone fixture against current Safari and Chromium, capture negotiation and reload results, and reproduce the documented compatibility matrix without the macOS application.

**Acceptance Scenarios**:

1. **Given** a supported browser client, **When** it connects to the fixture, **Then** the required endpoint, protocol version, handshake fields, and reload fields are captured.
2. **Given** CSS and full-page reload messages, **When** each supported browser receives them, **Then** the observed behavior is recorded as supported, partially supported, or unsupported.
3. **Given** browser behavior differs, **When** the matrix is published, **Then** the difference is documented without claiming untested compatibility.

---

### User Story 3 - Retire Architectural Unknowns (Priority: P1)

As the implementer, I need executable WebSocket and filesystem/permission prototypes so that the production architecture begins with proven platform boundaries.

**Why this priority**: Server-side WebSocket behavior, FSEvents callback bridging, and persistent folder access are the highest-risk platform boundaries.

**Independent Test**: Build and run both prototypes on Apple silicon, exercise the required normal/error cases, and trace their results to accepted ADRs.

**Acceptance Scenarios**:

1. **Given** the WebSocket prototype, **When** multiple clients connect, exchange protocol messages, disconnect, or encounter a port collision, **Then** the prototype produces the expected result and bounded diagnostics.
2. **Given** the filesystem prototype, **When** files are created, modified, renamed, or deleted and the root changes or events are dropped, **Then** typed events and recovery signals are observed.
3. **Given** a selected folder bookmark, **When** access is restored, becomes stale, or fails, **Then** restoration and repair behavior is demonstrated.
4. **Given** prototype evidence, **When** an architectural option is selected, **Then** its ADR records drivers, alternatives, consequences, limitations, and verification.

---

### User Story 4 - Establish Durable Governance (Priority: P2)

As the maintainer, I need a constitution and linked project records so that tasks, issues, decisions, solutions, and learning remain traceable across phases.

**Why this priority**: A long-running personal rewrite needs memory and quality gates, but governance supports rather than replaces the discovery evidence above.

**Independent Test**: Start with a plan task, record either a genuine research issue or a clearly marked controlled traceability example, link a proposed/verified solution and learning, close it in a sprint review, and verify that every record remains traceable by stable ID.

**Acceptance Scenarios**:

1. **Given** an unexpected problem, **When** it is recorded, **Then** it has a stable issue ID, status, severity, related task, evidence, and next action.
2. **Given** a reusable resolution, **When** it is verified, **Then** it links the issue, test/evidence, relevant task, and any architectural decision.
3. **Given** a completed task, **When** its checkbox is marked complete, **Then** completion evidence exists in the active Spec Kit `tasks.md` and the sprint review records the result.
4. **Given** a proposed exception to a constitutional rule, **When** it is evaluated, **Then** it is rejected, time-limited with compensating controls, or adopted through a versioned amendment.

---

### User Story 5 - Define Private Distribution Constraints (Priority: P2)

As the maintainer, I need the licence, asset, signing, hardened-runtime, and sandbox posture documented so that production work and private previews do not accumulate avoidable distribution debt.

**Why this priority**: These constraints shape assets and process boundaries but do not block the behavioral inventory or standalone protocol fixtures.

**Independent Test**: Review the distribution ADR and notice against cited repository evidence, inspect the asset inventory, and verify an empty signed hardened-runtime application on the target Mac.

**Acceptance Scenarios**:

1. **Given** historical code or notices are retained, **When** the notice is reviewed, **Then** original attribution and required terms remain intact and new work is distinguished.
2. **Given** a historical asset with uncertain provenance, **When** it is classified, **Then** it is excluded from the modern release path until replaced or permission is confirmed.
3. **Given** the intended private preview, **When** packaging constraints are recorded, **Then** signing, hardened runtime, sandbox status, and public-distribution boundaries are explicit.

### Edge Cases

- The archived binary does not launch, crashes, or requests unavailable services on modern macOS.
- Browser extensions are unavailable, unsigned, or behave differently from script-tag clients.
- Port 35729 is already occupied or restricted.
- Network.framework accepts a connection but does not provide the framing/control behavior required for a robust server.
- FSEvents coalesces paths, reports dropped events, observes a renamed root, or crosses a sleep/wake cycle.
- A bookmark resolves to a moved folder, is stale, or cannot begin security-scoped access.
- Research sources disagree or describe different protocol generations.
- Licence or asset provenance cannot be confirmed from primary evidence.
- A ledger entry would expose personal paths, credentials, or private source contents.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The phase MUST produce a behavior inventory covering project lifecycle, monitoring/filtering, browser negotiation, reload behavior, build flow, persistence, and expected error states.
- **FR-002**: Every inventory entry MUST include evidence, scope classification, and a future verification method.
- **FR-003**: The phase MUST provide sanitized protocol fixtures for valid and invalid handshakes and reload messages.
- **FR-004**: The phase MUST provide a repeatable browser fixture and compatibility matrix for current Safari and Chromium.
- **FR-005**: Browser research MUST distinguish observed behavior from inference and MUST NOT claim untested compatibility.
- **FR-006**: The phase MUST provide an executable Apple-silicon WebSocket server prototype that demonstrates bind, handshake, reload exchange, multiple clients, disconnect, malformed input, and port collision.
- **FR-007**: The WebSocket decision MUST be recorded in ADR-001 with considered alternatives and executable verification evidence.
- **FR-008**: The phase MUST provide an executable FSEvents prototype demonstrating create, modify, rename, delete, root change, dropped-event, start, and stop behavior.
- **FR-009**: The phase MUST demonstrate creation, restoration, stale detection, balanced access, and repair behavior for selected-folder bookmarks.
- **FR-010**: Monitoring and folder-access decisions MUST be recorded in ADR-002 with recovery and concurrency-boundary rules.
- **FR-011**: The phase MUST preserve required historical attribution in `NOTICE.md` and classify historical assets by provenance and intended treatment.
- **FR-012**: The private distribution posture MUST be recorded in ADR-003, including signing, hardened runtime, sandbox status, public-distribution boundary, and unresolved legal questions.
- **FR-013**: The project MUST maintain a versioned constitution with amendment and exception rules.
- **FR-014**: The project MUST maintain stable-ID ledgers/templates for issues, solutions, learnings, ADRs, and sprint reviews.
- **FR-015**: Every executable Phase 0 task MUST have a unique stable ID, checkbox state, and evidence rule.
- **FR-016**: Research artifacts MUST cite primary sources, executable observations, repository files/tests, or captured fixtures; uncited recollection MUST NOT be treated as fact.
- **FR-017**: Research prototypes MUST remain isolated from production modules and MUST NOT introduce production dependencies.
- **FR-018**: The phase MUST end with no unresolved architecture-blocking unknown; otherwise the relevant decision remains open and Phase 1 MUST NOT begin.
- **FR-019**: Any archived-binary observation MUST follow the constitution's static-inspection, hash/signature, disposable-environment, private-data, network, and stop-condition safeguards; the observation MAY be skipped when those safeguards cannot be met.

### Key Entities *(include if feature involves data)*

- **Behavior Record**: A user-visible outcome with evidence, v1/deferred/rejected classification, and future verification method.
- **Protocol Fixture**: Sanitized input/output data and expected interpretation for browser negotiation or reload behavior.
- **Compatibility Observation**: Browser/version, connection method, scenario, observed result, evidence, and support classification.
- **Research Finding**: Direct observation, source, limitations, interpretation, and consequence for later work.
- **Architecture Decision**: Status, drivers, considered options, decision, consequences, and verification evidence.
- **Ledger Record**: Stable ID, status, related task/artifacts, evidence, next action or disposition, and timestamps where applicable.
- **Asset Provenance Record**: Asset identity, source, known terms, intended treatment, and unresolved questions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of identified v1 behaviors have at least one evidence reference and one named future verification method.
- **SC-002**: The standalone fixture completes protocol negotiation and receives a reload command in both current Safari and current Chromium, or the exact unsupported case is reproducibly documented and fed back into scope.
- **SC-003**: The WebSocket prototype completes all seven required scenarios—bind, handshake, reload, multiple clients, disconnect, malformed input, and port collision—without a process crash.
- **SC-004**: The filesystem/access prototype completes create, modify, rename, delete, root-change, dropped-event, bookmark restore, and stale/repair scenarios with captured results.
- **SC-005**: ADR-001, ADR-002, and ADR-003 contain no unresolved decision placeholders and each links executable or primary-source evidence.
- **SC-006**: All Phase 0 task IDs are unique and all executable tasks have checkbox states; all completed tasks link or colocate their evidence.
- **SC-007**: A ledger traceability exercise can navigate from one genuine issue or clearly marked controlled example to its task, evidence, solution/decision, and sprint disposition without relying on conversation history.
- **SC-008**: A clean review finds no credentials, personal absolute paths, private source contents, or unclassified release assets in the new artifacts.
- **SC-009**: Phase 1 readiness review records zero open architecture-blocking issues and confirms constitution compliance.

## Assumptions

- Work is for personal use and private preview distribution unless a later specification changes that scope.
- The development host remains an Apple-silicon Mac with Xcode 26.3 or a compatible newer toolchain.
- Current browser versions available on the development Mac are acceptable research targets; exact versions are recorded with evidence.
- The original source, tests, and archived app are behavioral evidence, but production code will be newly implemented.
- Internet research uses primary sources where possible, including Apple documentation/SDK headers and maintained LiveReload repositories.
- Research prototypes may be discarded after their decisions and tests are captured.
- No production application feature beyond research harnesses/prototypes is delivered in this phase.
