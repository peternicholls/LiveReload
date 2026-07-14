# Feature Specification: Developer Workflow and Daily Usability

**Feature Branch**: `004-developer-workflow`

**Created**: 2026-07-14

**Status**: Draft — Phase 3 planning

**Input**: User description: "Prepare the next phase after the merged reload loop: configure and safely run optional project builds before reload, make failures diagnosable, and make the app comfortable to use from the menu bar during a full development day."

## User Scenarios & Testing

### User Story 1 - Configure a Safe Project Build (Priority: P1)

As a developer, I want to choose a project executable, arguments, working directory, environment additions, and timeout without editing configuration files so that the app can run my existing build command safely.

**Why this priority**: Build configuration establishes the process-execution trust boundary before orchestration work.

**Independent Test**: Configure a disposable fixture with an executable URL, arguments, working directory, environment additions, and timeout; save, relaunch, inspect the redacted summary, and verify invalid values are rejected without changing the previous valid configuration.

**Acceptance Scenarios**:

1. **Given** an enabled project with usable folder access, **When** the user enters valid structured values, **Then** the configuration is validated, persisted, and shown as a redacted summary.
2. **Given** an inaccessible executable or working directory, invalid timeout, or invalid environment key, **When** the user saves, **Then** the save is rejected with a specific correction and the prior valid configuration is preserved.
3. **Given** a saved build configuration, **When** the app is relaunched, **Then** the same structured values are restored without converting them into a shell command.

### User Story 2 - Build Before Reload Predictably (Priority: P1)

As a developer, I want a configured build to run before a reload and to see its output and result so that successful changes refresh my browser while failed changes do not hide the problem.

**Why this priority**: This connects safe process execution to the existing monitor-to-browser pipeline while making failure behavior explicit.

**Independent Test**: Use fixture executables that succeed, fail, time out, and wait for cancellation; trigger changes during and outside a build, and verify the visible result, bounded output, reload decision, and process cleanup for each case.

**Acceptance Scenarios**:

1. **Given** a project with no build configured, **When** a settled change batch arrives, **Then** the existing reload behavior occurs immediately.
2. **Given** a project with a valid build configured, **When** a settled change batch arrives, **Then** one build starts with the structured executable and arguments, output streams incrementally within a bounded history, and a reload occurs only after exit status zero.
3. **Given** a build that exits nonzero, cannot launch, times out, or is cancelled, **When** the result is known, **Then** the app reports the distinct failure, does not reload, and offers the next safe action.
4. **Given** a build is active, **When** additional file batches arrive, **Then** they coalesce into exactly one follow-up build using the accumulated changes after the active build ends.

### User Story 3 - Control the App from the Menu Bar (Priority: P2)

As a developer, I want the essential project and browser controls in the menu bar so that I can work with the main window closed and still understand the app's health.

**Why this priority**: A long-running developer utility must be low-friction during normal work.

**Independent Test**: Close the main window, open the menu-bar menu, and use keyboard-accessible commands to inspect health, pause/resume a project, trigger a manual reload, reopen the window, and quit while verifying the same actions are reflected in the app model.

**Acceptance Scenarios**:

1. **Given** the app is running with zero or more projects and browsers, **When** the menu-bar menu opens, **Then** it shows overall health, active projects, connected browser count, and clear empty/loading/error states.
2. **Given** an enabled project, **When** the user chooses pause, resume, or manual reload from the menu, **Then** the shared command route updates the project once and reports the resulting state.
3. **Given** light/dark appearance, reduced motion, keyboard navigation, or VoiceOver, **When** the menu is used, **Then** status meaning and action labels remain understandable without color alone.

### User Story 4 - Configure Defaults and Exclusions (Priority: P2)

As a developer, I want safe global defaults and per-project exclusions so that I can tune the utility to my workspace without hand-editing files or losing existing project setup.

**Why this priority**: Port, debounce, history, and ignore rules affect every project and must be explicit before all-day use.

**Independent Test**: Change each setting in a disposable fixture, restart the app, preview an ignore rule against sample paths, and reset to defaults; verify validation, persistence, migration, and non-destructive reset behavior.

**Acceptance Scenarios**:

1. **Given** the settings screen, **When** the user changes port, debounce, activity-history limit, default exclusions, or launch behavior, **Then** values are validated, persisted, and reflected in the affected service without restarting unrelated projects.
2. **Given** a project ignore rule, **When** the user previews it against included, excluded, hidden, Unicode, and nested paths, **Then** the preview explains the match and precedence without exposing unrelated absolute paths.
3. **Given** invalid or out-of-range settings, **When** the user saves, **Then** the app explains the correction and preserves the last valid value.

### User Story 5 - Recover from Expected Failures (Priority: P2)

As a developer, I want the app to explain and recover from lost folders, occupied ports, sleep/wake transitions, and failed builds so that a transient problem does not require rebuilding my setup.

**Why this priority**: Background tools are trusted only when their failure states are accurate, actionable, and non-destructive.

**Independent Test**: Inject folder loss, port conflict, sleep/wake or path transition, and build failure while projects are active; verify each state preserves configuration, avoids duplicate listeners/processes, and offers a direct recovery action.

**Acceptance Scenarios**:

1. **Given** a project root or folder bookmark becomes unavailable, **When** monitoring or a build needs it, **Then** the app stops only the affected work, preserves project configuration, and offers repair or retry.
2. **Given** the local endpoint is occupied or a lifecycle transition interrupts services, **When** recovery runs, **Then** the app reports the conflict, avoids duplicate servers/monitors, and offers a safe retry path.
3. **Given** a build fails or is cancelled, **When** the user opens activity, **Then** the visible history includes the result and next action but redacts environment values and unrelated source contents.

### Edge Cases

- A user clicks build, pause, resume, repair, or reload repeatedly while an earlier action is still running.
- A build emits more output than the configured history limit, exits without output, or ignores graceful termination.
- A file-change batch arrives while a build is starting, finishing, timing out, or being cancelled.
- The configured executable or working directory is moved, deleted, replaced, or points outside the selected project.
- An environment addition attempts an invalid key, a reserved key, or a value that would expose a secret in diagnostics.
- The app sleeps or wakes while monitoring, building, or reconnecting; a project is removed during an active build.
- The menu bar is opened while projects are loading, recovering, paused, or failed.
- Settings are migrated from an older version with missing, out-of-range, or unknown values.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST represent an optional build configuration as an executable URL, ordered argument array, working directory, validated environment additions, and timeout without a shell command string.
- **FR-002**: The system MUST validate executable access, working-directory access, timeout bounds, environment-key syntax, and required folder permissions before saving a build configuration.
- **FR-003**: The system MUST persist valid build configurations and restore them without changing their structured meaning.
- **FR-004**: The system MUST execute configured builds without invoking `/bin/sh` or interpolating user-controlled values into a shell command.
- **FR-005**: The system MUST stream stdout and stderr incrementally while enforcing documented output and activity-history bounds and redacting environment values.
- **FR-006**: The system MUST distinguish launch failure, nonzero exit, timeout, cancellation, and success as separate build results with actionable summaries.
- **FR-007**: The system MUST terminate owned child processes during cancellation, project removal, monitoring stop, app termination, and timeout, leaving no orphan process in supported test fixtures.
- **FR-008**: The system MUST allow at most one active build per project.
- **FR-009**: The system MUST coalesce changes received during an active build into exactly one follow-up build and MUST reload only for a successful build or immediately when no build is configured.
- **FR-010**: The system MUST expose queued, building, succeeded, failed, cancelled, and timed-out states through the existing keyboard-accessible state presentation.
- **FR-011**: The system MUST provide a menu-bar surface for overall health, project state, connected browser count, pause/resume, manual reload, opening the main window, and quitting.
- **FR-012**: The system MUST expose status meaning and commands through labels, keyboard equivalents, VoiceOver identifiers, and non-color-only cues.
- **FR-013**: The system MUST persist validated global port, debounce, history, default-exclusion, and launch-behavior settings with safe defaults and migration handling.
- **FR-014**: The system MUST provide per-project exclusion editing with match preview, documented precedence, reset-to-default behavior, and bounded/redacted path diagnostics.
- **FR-015**: The system MUST keep project configuration when folder access, ports, sleep/wake, path transitions, or builds fail and MUST offer a direct repair, retry, or correction action.
- **FR-016**: The system MUST make start, stop, pause, resume, repair, build, and reload actions idempotent under rapid repeated input and MUST prevent duplicate listeners or overlapping work.
- **FR-017**: The system MUST preserve Phase 2 loopback browser compatibility and no-build reload behavior while adding optional build gating.
- **FR-018**: The system MUST leave explicitly labelled shell mode, compiler presets, launch-at-login implementation, App Sandbox, broad network exposure, public distribution, and browser-extension bundling outside this feature.

### Key Entities

- **Build configuration**: A persisted, structured command definition owned by one project; contains executable, ordered arguments, working directory, environment additions, timeout, and enabled state.
- **Build run**: One owned child-process lifecycle with queued/running/finished state, bounded output, timing, exit classification, and cancellation reason.
- **Build batch**: The de-duplicated project change set that triggers one build and, when needed, one follow-up build after an active run.
- **Global settings**: Validated defaults for port, debounce, activity history, exclusions, and launch behavior, with migration metadata.
- **Menu-bar status**: A derived, accessible summary of app health, project states, browser count, and available commands.
- **Recovery state**: A preserved failure context with affected scope, redacted explanation, and direct repair/retry/correction action.

## Success Criteria

### Measurable Outcomes

- **SC-001**: In disposable-fixture tests, 100% of valid structured build configurations round-trip through persistence without shell conversion, and 100% of invalid configurations are rejected while the last valid value remains intact.
- **SC-002**: In fixture tests covering success, launch failure, nonzero exit, timeout, cancellation, and oversized output, every result is classified correctly, bounded, visible, and leaves no orphan child process.
- **SC-003**: Under a deterministic burst of at least 10,000 file events, each project has at most one active build, events during a build produce no more than one follow-up build, and reload is suppressed for every unsuccessful result.
- **SC-004**: With two active browser fixtures, a successful configured build produces exactly one reload batch and a failed build produces zero reloads; a project without a build preserves the Phase 2 immediate reload behavior.
- **SC-005**: UI and accessibility tests can operate project health, pause/resume, manual reload, settings, and recovery from the menu bar with the main window closed, without relying on color alone.
- **SC-006**: Injected folder, port, sleep/wake, and project-removal failures preserve unrelated projects and leave no duplicate monitor, server, or build owner after recovery.
- **SC-007**: A five-minute idle sample with two active projects and one browser remains below 1% CPU, and bounded output/history limits remain within documented memory budgets.
- **SC-008**: Debug and Release verification for affected targets passes with warnings treated as errors, relevant unit/integration/UI/end-to-end checks, and updated user/developer documentation before the sprint gate closes.

## Assumptions

- Users provide an executable already installed on the Mac; compiler-specific presets and package-manager discovery are deferred.
- The Phase 1 project store, folder-access repair flow, activity-history redaction, and accessibility baseline remain the foundation and are extended rather than replaced.
- The Phase 2 local-only browser endpoint and protocol behavior remain unchanged for projects without a build configuration.
- Build commands run only after the user enables them for a project; there is no automatic project discovery or launch-at-login implementation in this feature.
- The launch-behavior setting covers supported in-app project/runtime startup policy only; launch-at-login registration remains deferred.
- A bounded in-memory output/history policy is acceptable; durable raw stdout, full environments, credentials, and unrelated source contents are out of scope.
- macOS 15+, Apple silicon, Swift 6.2 strict concurrency, SwiftUI, and existing Apple platform frameworks remain the supported implementation baseline.
