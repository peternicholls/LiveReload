# Feature Specification: Modern Foundation

**Feature Branch**: `002-modern-foundation`

**Created**: 2026-07-13

**Status**: Ready for planning

**Input**: Phase 1 of the Apple-silicon LiveReload rewrite: establish a clean native app, durable project lifecycle, and bounded diagnostics before production monitoring, browser reload, or build execution.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Restore a trusted project list (Priority: P1)

As a developer, I can add a folder as a LiveReload project and find it restored after relaunch so that setup is not repeated each time I open the app.

**Why this priority**: A durable project list and retained folder access are the minimum foundation for every later workflow.

**Independent Test**: Add a temporary folder, configure its display name and enabled state, relaunch the app, and verify the same project identity, settings, and access state are restored.

**Acceptance Scenarios**:

1. **Given** an empty project list, **When** I select a valid folder, **Then** the app adds one enabled project with a stable identity and a visible folder name.
2. **Given** a saved project list, **When** the app relaunches, **Then** each project and its enabled/name settings are restored without duplicate entries.
3. **Given** a folder is selected twice, **When** the second selection is confirmed, **Then** the app rejects the duplicate based on normalized folder identity and keeps the original project unchanged.
4. **Given** an existing project has stale, missing, or denied folder access, **When** the app restores it, **Then** it preserves the project and presents an actionable repair state rather than deleting it.

---

### User Story 2 - Start from a native, verifiable app baseline (Priority: P1)

As a maintainer, I can build, test, and launch a clean Apple-silicon macOS application from documented commands so that later work does not inherit the legacy runtime stack.

**Why this priority**: Every subsequent feature depends on a reproducible Swift 6.2 app and a UI-independent core.

**Independent Test**: On an Apple-silicon Mac, run the documented verification command to build Debug and Release configurations, run core and UI tests, inspect the resulting executable architecture, and confirm no legacy runtime or third-party package is required.

**Acceptance Scenarios**:

1. **Given** a clean checkout, **When** the documented verification command runs, **Then** Debug and Release builds complete with warnings treated as errors and all configured tests pass.
2. **Given** the built app, **When** it launches, **Then** it runs natively on arm64 and targets macOS 15 or later.
3. **Given** the core package, **When** its models and persistence behaviors are tested, **Then** the tests do not import SwiftUI or AppKit.

---

### User Story 3 - Manage projects accessibly (Priority: P2)

As a developer, I can inspect, rename, enable, repair, and remove projects through a clear keyboard-accessible macOS interface.

**Why this priority**: A retained project is useful only if its status and corrective actions are clear without relying on developer tooling.

**Independent Test**: Using keyboard navigation and VoiceOver labels, add a temporary folder, rename it, disable it, enter a repair state, repair it, and remove it while verifying disk contents remain untouched.

**Acceptance Scenarios**:

1. **Given** no projects, **When** I open the app, **Then** an empty state explains the next action and exposes a keyboard-accessible add control.
2. **Given** a listed project, **When** I rename or enable/disable it, **Then** the visible state updates and survives relaunch.
3. **Given** a repair-required project, **When** I choose repair and select a replacement folder, **Then** the project retains its identity and settings while its folder access is replaced.
4. **Given** a project I choose to remove, **When** I confirm removal, **Then** only app configuration is removed and the source folder remains on disk.

---

### User Story 4 - Understand local app state safely (Priority: P2)

As a developer, I can see a small, useful history of local app events and failures without exposing private paths or secrets.

**Why this priority**: Clear diagnostics make persistence and access failures actionable before monitoring and reload services exist.

**Independent Test**: Trigger a recoverable persistence or permission error, inspect the in-app activity history, and verify it uses a stable category/severity, redacts sensitive path details, and remains bounded in size.

**Acceptance Scenarios**:

1. **Given** a recoverable storage or access failure, **When** it occurs, **Then** the app records an actionable event with category, severity, timestamp, and safe summary.
2. **Given** more activity than the configured history capacity, **When** newer events arrive, **Then** the oldest events are discarded and the history stays bounded.
3. **Given** a path that contains private directory components, **When** it appears in diagnostics, **Then** the stored/displayed event follows the project redaction policy.

### Edge Cases

- The project configuration file is missing, unreadable, corrupt, or written by a later unsupported schema version.
- A persisted bookmark resolves stale, points to a moved/deleted folder, or cannot begin access.
- A replacement folder duplicates another project or is cancelled by the user.
- The app is relaunched while configuration replacement was interrupted; the last valid configuration remains recoverable.
- A project name is empty, excessively long, or contains only whitespace.
- The project list is empty, contains enough entries to require navigation, or is viewed in light/dark appearance with enlarged text.
- Diagnostics include an error with an absolute local path, command-like text, or long underlying error details.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a native arm64 macOS 15+ application target and a UI-independent local core target, both built with Swift 6.2 strict concurrency and warnings treated as errors.
- **FR-002**: The repository MUST provide one documented terminal verification command that builds Debug and Release configurations and runs configured core and UI tests.
- **FR-003**: The modern app and its core targets MUST NOT require CocoaPods, Node.js, Ruby, CoffeeScript, or a third-party package for this phase.
- **FR-004**: The system MUST represent each project with a stable identity, display name, enabled state, folder-access state, build configuration placeholder, ignore-rule placeholder, and versioned configuration envelope.
- **FR-005**: Project configuration MUST be Codable, Sendable, independently testable from SwiftUI/AppKit, and reject unsupported future schema versions without overwriting the source data.
- **FR-006**: The system MUST persist project configuration atomically in the user’s Application Support location and preserve a corrupt/unreadable source file for diagnosis before returning a safe default state.
- **FR-007**: The system MUST prevent duplicate projects using normalized folder identity, not a display-name comparison.
- **FR-008**: The system MUST create, resolve, begin, and end security-scoped folder access through an isolated adapter with balanced access lifecycle handling.
- **FR-009**: A stale, corrupt, missing, or denied folder bookmark MUST produce a repair-required project state; it MUST NOT silently remove the project.
- **FR-010**: Repairing folder access MUST replace only bookmark/access data while retaining the project identity, name, enabled state, and other configuration.
- **FR-011**: The project-list interface MUST support add, inspect, rename, enable/disable, repair, and confirmed configuration-only removal operations.
- **FR-012**: The interface MUST provide keyboard-operable controls, accessibility labels, logical VoiceOver order, readable empty/permission/missing-folder states, and light/dark appearance support for the project-management flow.
- **FR-013**: The system MUST record bounded local activity events with stable severity and category values for app, storage, folder access, monitoring, network, build, and pipeline domains.
- **FR-014**: Activity events and persisted diagnostics MUST redact sensitive absolute-path components and MUST NOT retain credentials, full environment values, or source-file contents.
- **FR-015**: The phase MUST include unit, integration, UI, and clean-account smoke evidence appropriate to its targets; tests MUST cover model round trips, defaults, invalid data, future-version rejection, corrupt-store recovery, duplicates, bookmark stale/failure/repair behavior, activity capacity, and redaction.
- **FR-016**: This phase MUST NOT claim production filesystem monitoring, browser reload serving, browser protocol compatibility, or build execution; later feature specifications own those behaviors.
- **FR-017**: The project MUST maintain `VERSIONING.md` and `CHANGELOG.md`; every releasable change MUST have an explicit version/changelog disposition before tag or distribution.
- **FR-018**: The project MUST maintain `docs/project-ledger/software-inclusions.md` for every production, development, copied-source, generated-source, asset, tool, and service inclusion, with origin, version/hash, licence evidence, usage, attribution/distribution impact, and review status.
- **FR-019**: Unknown or unverified inclusion provenance/licensing MUST block release inclusion until resolved or explicitly excluded; the register MUST NOT make unsupported legal claims.
- **FR-020**: The project MUST maintain user and developer guides that state only verified behavior and are reviewed/updated with every applicable user workflow, diagnostic, compatibility, build/test, release, dependency, or attribution change.

### Key Entities

- **Project Configuration**: Versioned persistent record for one selected project, including stable identity, display name, enabled state, bookmark/access metadata, build placeholder, ignore placeholder, and user-visible status.
- **Configuration Envelope**: The versioned outer record that permits migration, default handling, and rejection of unsupported future data.
- **Folder Access State**: Current state of a selected folder’s bookmark/access lifecycle, including available, repair-required, missing, and denied conditions.
- **Project Store**: The persistence boundary that loads, validates, atomically replaces, and recovers project configuration.
- **Activity Event**: A bounded, redacted record with category, severity, timestamp, safe summary, and optional project identity.
- **Project List State**: UI-facing collection and selection state that maps project/store/access outcomes to accessible controls and actionable empty/error states.
- **Software Inclusion Record**: Stable record of a code, asset, tool, framework, generator, or service inclusion and its origin, licence evidence, usage, attribution impact, and review state.
- **Guide Coverage Record**: The documented supported behavior, setup, recovery, limitation, and developer workflow affected by a change.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A clean Apple-silicon checkout completes the documented Debug/Release build and configured test command with zero warnings and zero failures.
- **SC-002**: The launched modern app is arm64-only, targets macOS 15 or later, and has no runtime dependency on the legacy toolchain or bundled scripting runtimes.
- **SC-003**: In automated temporary-directory tests, 100% of valid project configurations round-trip with stable identity/settings, and corrupt or unsupported-future data leaves a recoverable source plus a safe default state.
- **SC-004**: Duplicate-folder, stale-bookmark, failed-bookmark, and repair scenarios each have passing tests; repair retains the project identity and non-access settings in every tested case.
- **SC-005**: The primary add/rename/enable/repair/remove journey passes an XCUITest with accessibility identifiers and keyboard-operable controls; removal leaves the selected source folder on disk.
- **SC-006**: Activity-history tests demonstrate the configured capacity limit and redact all test absolute paths while retaining actionable category and severity.
- **SC-007**: The Phase 1 sprint review links every completed task to evidence, records any exception/issue, and leaves no unresolved critical or high-severity security defect.
- **SC-008**: A documentation review confirms the version/changelog state, inclusion-register completeness, NOTICE impact, and user/developer-guide accuracy for every Phase 1 capability that is claimed as supported.

## Assumptions

- The target host is an Apple-silicon Mac using Xcode 26.3 or a compatible newer toolchain.
- The modern app’s initial bundle identifier and signing team may use development-only values until a later packaging decision changes them; hardened-runtime requirements from ADR-003 remain binding.
- The project list is private, local-only data with no cloud sync, telemetry, account system, or sharing feature in this phase.
- A standard macOS folder-selection dialog is the acceptable access-granting interaction for this phase.
- Build-command and ignore-rule records are stored as validated placeholders; executing builds and applying monitoring filters are deferred to later phases.
- The Phase 0 constitution, ADR-001 through ADR-003, behavior inventory, browser evidence, and ledger records remain binding inputs.
