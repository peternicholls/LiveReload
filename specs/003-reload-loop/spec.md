# Feature Specification: Minimum Useful Reload Loop

**Feature Branch**: `003-reload-loop`

**Created**: 2026-07-13

**Status**: Complete — Phase 2 readiness PASS

**Input**: User description: "Deliver the Phase 2 minimum useful LiveReload loop: selected enabled projects can be monitored safely, file-change bursts are filtered and coalesced, modern browser clients connect only over loopback and receive standards-compatible protocol 7 reload messages, and the app exposes monitoring, connection, and recovery states. Preserve Phase 1 storage/bookmark guarantees; defer build execution, App Sandbox, and public distribution."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatically Refresh a Connected Browser (Priority: P1)

As a developer, I want saving a supported source file in an enabled project to refresh my connected browser so that I can see my changes without manually reloading the page.

**Why this priority**: This is the product's first end-to-end value loop; without it, monitoring and browser connectivity have no user outcome.

**Independent Test**: With one disposable project and one compatible browser fixture, connect the browser, edit a CSS file and an HTML file, and verify the browser receives exactly one appropriate refresh request for each settled edit.

**Acceptance Scenarios**:

1. **Given** an enabled project with usable folder access and a connected compatible browser, **When** a supported file is saved and the resulting change burst settles, **Then** the browser receives one refresh request that represents the changed file.
2. **Given** an enabled project with usable folder access and a connected compatible browser, **When** a stylesheet is saved, **Then** the refresh request asks the browser to update the stylesheet without a full page refresh when the browser supports it.
3. **Given** a connected compatible browser, **When** no project file changes occur, **Then** the app does not send a refresh request.

---

### User Story 2 - Start and Trust Project Monitoring (Priority: P1)

As a developer, I want to start and stop monitoring for a project and see its real state so that I know whether saving files will trigger browser refreshes.

**Why this priority**: A background utility must make its active, stopped, and failed states visible and controllable before users can trust automated behavior.

**Independent Test**: Use a disposable project to start monitoring, generate create/modify/rename/delete changes, stop monitoring, and verify that only the active period produces project activity.

**Acceptance Scenarios**:

1. **Given** an enabled project with usable access, **When** the user starts monitoring, **Then** the project visibly enters an active state without creating duplicate monitoring work.
2. **Given** an actively monitored project, **When** the user stops monitoring, **Then** the project visibly enters a stopped state and later file changes do not trigger refreshes.
3. **Given** a project whose folder access becomes unavailable, **When** monitoring cannot continue, **Then** monitoring stops safely, the project configuration is preserved, and the user sees a recovery action.

---

### User Story 3 - Control Noisy File Changes (Priority: P2)

As a developer, I want common generated files and my configured exclusions ignored, while rapid saves are grouped, so that browsers refresh for meaningful work without flicker or reload storms.

**Why this priority**: Filtering and grouping make the automatic loop usable in real projects rather than only in a clean demonstration folder.

**Independent Test**: Generate a mixed burst of source, version-control, dependency, build-output, temporary, hidden, Unicode, and user-excluded paths; verify the resulting visible change activity and refresh requests match the documented rules.

**Acceptance Scenarios**:

1. **Given** an active project, **When** only default-excluded or user-excluded files change, **Then** no refresh request is sent.
2. **Given** an active project, **When** the same supported file changes repeatedly during one short save burst, **Then** the browser receives one refresh request after the burst settles.
3. **Given** an active project, **When** multiple supported files change during one short save burst, **Then** the user can see one ordered summary of the affected paths without exposing unrelated absolute paths.

---

### User Story 4 - Recover From Browser and Folder Failures (Priority: P2)

As a developer, I want clear recovery states for unavailable folders, interrupted monitoring, and local connection problems so that I can restore automatic refresh without losing project setup.

**Why this priority**: Long-running local tools encounter permission, folder, and port failures; silent degradation would make the reload loop unreliable.

**Independent Test**: Simulate unavailable folder access, monitoring interruption, an occupied local port, malformed client input, and browser disconnects; verify each condition preserves unrelated work and gives an actionable outcome.

**Acceptance Scenarios**:

1. **Given** a local connection endpoint is already in use, **When** the app starts browser connectivity, **Then** it remains usable, reports the conflict, and offers a safe retry path.
2. **Given** one connected browser sends invalid input or disconnects, **When** the condition is detected, **Then** that browser is isolated and other connected browsers continue to receive valid refresh requests.
3. **Given** monitoring loses its root or cannot recover its change stream, **When** the failure occurs, **Then** the app does not claim that monitoring is active and explains the next safe action.

### Edge Cases

- A monitored root is renamed, deleted, unmounted, or becomes inaccessible while the app is running.
- The change source reports that events may have been lost or cannot determine individual affected files.
- A save operation produces many repeated, reordered, or Unicode-named paths.
- A symbolic link points outside the selected project, or a change occurs in a hidden file that is not explicitly excluded.
- A client connects using an unsupported negotiation, incorrect endpoint, oversized input, or an unmasked browser message.
- The local connection endpoint becomes unavailable during startup, shutdown, or restart.
- Monitoring is started or stopped repeatedly, including while a change burst is waiting to settle.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST let a user start and stop monitoring for each enabled project whose folder access is usable.
- **FR-002**: The system MUST represent stopped, starting, active, recovering, and failed monitoring states in a keyboard-accessible, non-color-only interface.
- **FR-003**: The system MUST process create, modify, rename, delete, root-change, and event-loss signals without losing project configuration.
- **FR-004**: The system MUST ensure repeated start or stop requests leave each project in one consistent state and do not create duplicate background monitoring.
- **FR-005**: The system MUST preserve least-privilege folder access and require explicit repair when access is unavailable or stale.
- **FR-006**: The system MUST ignore version-control metadata, common dependency and build-output locations, editor temporary files, and user-configured exclusions according to documented precedence rules.
- **FR-007**: The system MUST retain meaningful hidden files unless a default or user exclusion matches them.
- **FR-008**: The system MUST group a short burst of supported file changes into one ordered, de-duplicated refresh decision after a documented settling interval between 100 and 500 milliseconds.
- **FR-009**: The system MUST accept browser clients only through a local-only endpoint and MUST not expose the endpoint to other network hosts by default.
- **FR-010**: The system MUST accept only the documented LiveReload endpoint and a compatible protocol negotiation before a client can receive refresh requests.
- **FR-011**: The system MUST support multiple compatible browser clients and report their current connection count.
- **FR-012**: The system MUST send one standards-compatible refresh request per settled change batch for projects without a configured build workflow.
- **FR-013**: The system MUST distinguish stylesheet changes from other supported changes so that compatible browsers can update styles without unnecessarily refreshing the full page.
- **FR-014**: The system MUST isolate malformed, unsupported, oversized, or disconnected browser clients so they cannot stop valid clients or project monitoring.
- **FR-015**: The system MUST report unavailable folders, interrupted monitoring, local endpoint conflicts, and browser failures with a safe summary, preserved state, and next action.
- **FR-016**: The system MUST keep monitoring, connection, and file-change diagnostics bounded and must not expose full absolute paths, credentials, bookmark data, or unrelated source contents.
- **FR-017**: The system MUST provide a manual refresh action for a selected active project without requiring a file change.
- **FR-018**: The system MUST leave build execution, broad network exposure, App Sandbox support, public distribution, browser-extension bundling, and URL override outside this feature's scope.

### Key Entities

- **Monitoring session**: The user-visible lifecycle for observing one enabled project, including its current state, recovery reason, and most recent settled change batch.
- **Change batch**: The ordered, de-duplicated set of meaningful project changes that settle together and lead to at most one refresh decision.
- **Exclusion rule**: A default or user-defined path rule that determines whether a change participates in a batch.
- **Browser connection**: A compatible local browser participant with negotiated capability, lifecycle state, and safe diagnostic identity.
- **Refresh decision**: The user-observable outcome for a settled change batch or manual action, including whether it updates styles or requests a full page refresh.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In an automated disposable-project and browser-fixture test, 100% of supported HTML and stylesheet save scenarios produce exactly one appropriate refresh request after the configured settling interval.
- **SC-002**: In automated lifecycle tests, 100% of start, stop, repeated-start, repeated-stop, folder-loss, root-change, and event-loss scenarios end in an accurate visible monitoring state with preserved project configuration.
- **SC-003**: In a mixed 10,000-event test burst, excluded paths produce zero refresh requests and each distinct supported change batch produces no more than one refresh decision.
- **SC-004**: Two compatible browser fixtures can remain connected while a malformed or disconnected third client produces no refresh failure for the valid clients.
- **SC-005**: A five-minute idle sample for one active project remains below 1% CPU, and every start/stop cycle releases its monitoring and folder-access resources.
- **SC-006**: Keyboard and UI automation can start and stop monitoring, observe active/recovery/failure states, trigger manual refresh, and verify project configuration remains intact after each recovery scenario.
- **SC-007**: Release verification passes Debug and Release builds with warnings treated as errors, relevant unit/integration/UI/end-to-end tests, privacy checks, and Safari plus Chromium compatibility evidence.

## Assumptions

- The Phase 1 project store, folder-access repair flow, redacted activity history, and accessibility baseline remain the durable foundation for this feature.
- The existing Phase 0 browser fixtures and accepted protocol decisions are valid compatibility evidence; this feature must re-run them against the production path before claiming support.
- Monitoring begins only after a user explicitly starts it for an enabled project; automatic startup restoration and launch-at-login are deferred.
- Default exclusions cover common version-control, dependency, build-output, and editor-temporary locations; exact user-rule syntax and precedence will be resolved during planning and recorded before implementation.
- The local connection endpoint uses the established LiveReload compatibility contract and remains local-only by default.
- A project with an optional build workflow continues to retain its configuration, but this feature does not execute it or delay refreshes for it.
