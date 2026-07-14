# LiveReload Modern Apple Silicon Rewrite Plan

## Direction

Build a new, native macOS LiveReload application for Apple silicon rather than porting the 2016 code line-by-line. Preserve the LiveReload workflow and wire protocol, use the legacy repository as a behavioral reference, and leave the historical targets intact until the replacement proves parity for the chosen v1 scope.

The development baseline is Xcode 26.3 on arm64 macOS 26.5.2. The proposed application baseline is Swift 6.2 language mode with strict concurrency, an arm64-only Debug/Release build, and macOS 15.0 as the initial deployment target. macOS 15 keeps the implementation modern while retaining more practical reach than targeting macOS 26 alone.

## Requirements Summary

### Version 1 scope

- Native SwiftUI application with an AppKit bridge only where macOS APIs require it.
- Menu-bar presence plus a normal project-management window.
- Add and remove watched project folders using `NSOpenPanel`.
- Persist folder access using security-scoped bookmarks.
- Monitor project trees using FSEvents, coalesce bursts, and apply configurable ignore rules.
- Serve the standard LiveReload WebSocket endpoint on port 35729, including the protocol 7 handshake and reload command.
- Show connected-browser count, monitoring status, file events, reloads, and actionable errors.
- Allow an optional per-project build command, executed without a shell by default as an executable plus arguments.
- Trigger a reload after a successful build; report output and suppress reload after failure.
- Support start/stop monitoring, manual reload, launch at login, and restoration after relaunch.
- Run natively on Apple silicon without Rosetta, embedded Node.js, CoffeeScript, Ruby, CocoaPods, or the historical compiler plugins.

### Explicitly deferred

- Intel builds and macOS versions older than 15.
- Mac App Store submission and App Sandbox certification.
- Automatic Sass/LESS/CoffeeScript/TypeScript compiler discovery.
- The legacy `.lrplugin` format and embedded toolchains.
- Windows support, telemetry/news, licensing UI, Paddle, Sparkle, URL override, remote access, and public binary distribution.
- A bundled browser extension. Standard LiveReload browser extensions and script injection remain compatible through the protocol.

## Evidence From the Existing Repository

- The existing `develop` branch describes itself as transitional and requires Xcode 6, Node 0.10, CoffeeScript, Grunt, and optionally Ruby 1.8.7 (`README.md:42-96`). These are replacement boundaries, not dependencies to upgrade.
- The licence permits building and modification and becomes additionally MIT after two years without official binary releases, while requiring retained notices in copies (`README.md:7-33`). Preserve the original notice and add a clear modernization notice.
- The unfinished application boots through an obsolete Swift 2.3 `@NSApplicationMain` delegate and eagerly loads plugins (`LiveReload/Source/Application/AppDelegate.swift:1-24`). The new app should use the modern SwiftUI `App` lifecycle.
- The old prototype contains developer-specific absolute project paths (`LiveReload/Source/Application/App.swift:4-15`). No legacy persisted state should be migrated implicitly.
- The legacy backend is a Node subprocess connected through stdin/stdout (`mac/backend/lib/main.js:1-18`) and composes server/reloader/message-parser services (`mac/backend/lib/endpoint.js:1-20`). V1 replaces this process boundary with in-process Swift actors.
- The Xcode projects target macOS 10.10/10.11 and Swift 2.3 (`LiveReload/LiveReload.xcodeproj/project.pbxproj:540-665`, `LRProjectKit/LRProjectKit.xcodeproj/project.pbxproj:409-512`, `LRActionKit/LRActionKit.xcodeproj/project.pbxproj:691-794`). Trying to migrate these projects in place would mix mechanical conversion with architectural replacement.
- Protocol 7 and reload-message behavior are documented in `node_modules/livereload-protocol/lib/parser.coffee:52-80`, while the historical server tests demonstrate the reload request shape in `node_modules/livereload-service-server/test/server_test.coffee:33-35`.

## Proposed Architecture

Create a new `ModernLiveReload/` Xcode project beside the legacy code. Use a small app target and locally defined Swift packages so core behavior is testable without launching the UI.

```text
ModernLiveReload/
├── LiveReload.xcodeproj
├── App/
│   ├── LiveReloadApp.swift
│   ├── AppModel.swift
│   ├── MenuBar/
│   ├── Projects/
│   ├── Activity/
│   └── Settings/
├── Packages/LiveReloadCore/
│   ├── Sources/LiveReloadModel/
│   ├── Sources/LiveReloadMonitoring/
│   ├── Sources/LiveReloadProtocol/
│   ├── Sources/LiveReloadBuild/
│   └── Tests/
└── LiveReloadUITests/
```

### Runtime ownership

- `AppModel` (`@MainActor`, `@Observable`) owns view-facing state and coordinates services.
- `ProjectStore` persists a versioned Codable document in Application Support and resolves security-scoped bookmarks.
- One `ProjectMonitor` actor per active project wraps FSEvents, normalizes paths, filters ignores, and debounces batches.
- `ReloadServer` actor owns the listener and browser sessions. Protocol parsing is a pure Swift module with fixture tests.
- `BuildRunner` actor executes a structured executable/argument configuration through `Process`, streams output, supports cancellation and timeout, and never interpolates untrusted strings into `/bin/sh`.
- `ProjectPipeline` actor serializes each project's change → debounce → build → reload flow and prevents overlapping builds.
- Unified `Logger` categories feed both OSLog and a bounded in-app activity history.

## Delivery Model

- **Cadence:** Sprint 0 is one week; implementation sprints are two weeks. For a part-time personal project, treat each “week” as a capacity unit and keep the ordering rather than forcing calendar dates.
- **Capacity rule:** commit to one primary vertical slice plus tests and documentation per sprint. Pull stretch work only after the sprint acceptance gate passes.
- **Story sizing:** S is normally under one focused day, M is one to three days, and L is three to five days. Any XL item must be split before entering a sprint.
- **Definition of Ready:** the story has observable acceptance criteria, dependencies are complete, test fixtures exist or are explicitly tasked, and unresolved research has an owner/output/time-box.
- **Definition of Done:** implementation, automated tests, accessibility/error states where relevant, developer documentation, and the sprint demo all pass on an Apple-silicon Mac.
- **Research rule:** every spike is time-boxed and ends with an artifact: an ADR, compatibility matrix, executable prototype, benchmark, or captured fixture. A spike cannot end with only notes.
- **Tracking:** story IDs are stable (`R`, `F`, `P`, `M`, `W`, `B`, `U`, `Q`, `D`). Task checkboxes are the executable backlog and should be copied into issues only when that sprint starts.

### Spec Kit phase protocol

Each roadmap phase is delivered as its own numbered Spec Kit feature. The parent roadmap describes intent and sequencing; the active feature's `specs/NNN-short-name/tasks.md` is canonical for execution and completion evidence.

For every phase, in order:

1. **Specify:** create a new feature branch/directory with `speckit.specify`; define prioritized, independently testable user stories, edge cases, functional requirements, entities, measurable outcomes, assumptions, and a passing requirements checklist.
2. **Clarify when necessary:** run `speckit.clarify` only for materially branching unknowns that cannot be resolved from repository or primary-source evidence. Clarifications are incorporated into the specification before planning.
3. **Plan:** run `speckit.plan`; pass the constitution gate, resolve technical unknowns in `research.md`, produce `data-model.md`, relevant contracts, `quickstart.md`, and pass the post-design constitution gate.
4. **Tasks:** run `speckit.tasks`; generate dependency-ordered, checkbox-tracked tasks grouped by user story with exact paths, test-first work where applicable, parallel markers, requirement traceability, and explicit checkpoints.
5. **Analyze:** run `speckit.analyze` before implementation and again before phase closure; critical/high inconsistencies block progress.
6. **Implement and verify:** execute only the active phase's approved `tasks.md`; update ledgers and sprint evidence as work proceeds.
7. **Close and hand off:** revalidate requirements, constitution, tasks, ADRs, tests, and phase exit criteria; update this parent roadmap; then start the next phase with a new `speckit.specify` feature rather than appending work to the previous feature.

Proposed feature sequence (exact numbers are assigned by Spec Kit at creation time):

| Roadmap phase | Proposed short name | Expected sprint coverage | Status |
|---|---|---|---|
| Phase 0 — Discovery and decision lock | `discovery-baseline` | Sprint 0 | `001` complete; Phase 1 short name: `modern-foundation` |
| Phase 1 — Modern foundation and project lifecycle | `modern-foundation` | Sprints 1–2 | `002` complete; final verification passed 27 core tests, 6 app tests, and 5 UI tests |
| Phase 2 — Minimum useful reload loop | `reload-loop` | Sprints 3–4 | `003` complete; final verification passed 92 core tests, 10 app tests, 10 UI tests, and production Safari/Chromium file-to-browser evidence |
| Phase 3 — Developer workflow and daily usability | `developer-workflow` | Sprints 5–6 | Not specified |
| Phase 4 — Quality, security, and private preview | `private-preview` | Sprints 7–8 | Not specified |

Later phase specifications may refine their roadmap stories and tasks, but may not silently weaken the constitution, prior accepted ADRs, or version 1 boundaries. Any such change requires an explicit amendment or superseding ADR.

### Checkbox and evidence rules

- `[ ]` not started, `[>]` in progress, `[!]` blocked, and `[x]` complete. GitHub only renders the first and last as native task states; the middle states remain intentionally searchable text.
- A task becomes `[x]` only when its code/documentation and specified verification evidence are complete.
- Add a short evidence link or sprint-review reference to a checked task when the proof is not obvious from the same commit.
- Stories and sprint gates remain open until every required child task and acceptance criterion passes.
- Unexpected work is recorded as an `ISS-NNN` ledger entry and linked to the originating task; it must not be hidden inside an unrelated checkbox.
- The governing principles are in `.specify/memory/constitution.md`; status vocabulary and record templates are in `docs/project-ledger/README.md`.

## Phases, Stories, Sprints, and Tasks

### Phase 0 — Discovery and decision lock

**Outcome:** establish what must remain compatible, prove the riskiest Apple APIs, and freeze v1 boundaries before creating production architecture.

#### Sprint 0 — Research and behavioral baseline (one week)

**Sprint goal:** produce enough executable evidence to choose the WebSocket, monitoring, security, and packaging approaches without resurrecting legacy dependencies.

**R-01 — Inventory observable legacy behavior (M)**
As the rewrite maintainer, I want a behavior inventory so that implementation follows user-visible outcomes instead of old internal architecture.

Acceptance criteria:

- Inventory covers project lifecycle, file filtering, browser handshake, reload messages, CSS/image refresh behavior, build flow, error states, and persistence.
- Each behavior is marked `v1`, `deferred`, or `rejected`, with a source reference or captured observation.
- No v1 behavior depends on running Node 0.x or an obsolete compiler.

Tasks:

- [x] `R-01.1` Tag the untouched fork baseline and record upstream/develop SHA.
- [x] `R-01.2` Trace the historical protocol parser, server, project lifecycle, ignore rules, and build trigger paths.
- [x] `R-01.3` Run the archived app under Rosetta if safe and possible; capture screenshots and event sequences. If it cannot run, record the blocker and use source/tests as evidence.
- [x] `R-01.4` Write `docs/modernization/behavior-inventory.md` with v1/deferred/rejected classifications.
- [x] `R-01.5` Create sanitized JSON fixtures for valid/invalid handshakes and reload messages.

**R-02 — Validate current browser compatibility (M)**
As a user, I want modern browser clients to connect without a bespoke extension so that the app is immediately useful.

Acceptance criteria:

- At least Safari and Chrome/Chromium are tested with a maintained LiveReload client or direct protocol fixture.
- Required protocol versions, endpoint path, headers, and message fields are documented.
- Any CSS hot-swap differences are captured in a compatibility matrix.

Tasks:

- [x] `R-02.1` Identify the maintained LiveReload browser client and its protocol expectations from primary source/documentation.
- [x] `R-02.2` Build a minimal local HTML/CSS/JS browser fixture independent of the macOS app.
- [x] `R-02.3` Revalidate Safari handshake and corrected CSS reload traffic; Chromium and Safari passed.
- [x] `R-02.4` Save `docs/modernization/browser-compatibility.md` and commit reusable fixtures.

**R-03 — Prototype Network.framework WebSocket serving (L)**
As the implementer, I want to prove the server API before committing architecture so that protocol work does not stall inside UI development.

Acceptance criteria:

- An executable Swift prototype binds to `127.0.0.1:35729`, accepts `/livereload`, and exchanges a protocol 7 handshake and reload command.
- The prototype demonstrates multiple clients, disconnect detection, and a visible port-in-use error.
- ADR-001 chooses Network.framework, a minimal local RFC 6455 implementation, or a specifically justified dependency.

Tasks:

- [x] `R-03.1` Research current Network.framework server-side WebSocket support using Apple documentation and SDK headers.
- [x] `R-03.2` Build a throwaway command-line prototype under `Research/WebSocketPrototype/`.
- [x] `R-03.3` Test it against the Sprint 0 browser fixture and malformed frames.
- [x] `R-03.4` Record latency, API limitations, and decision in `docs/adr/001-websocket-server.md`.

**R-04 — Prototype FSEvents and permission lifecycle (M)**
As a user, I want reliable watching across restart, rename, and sleep so that reloads do not silently stop.

Acceptance criteria:

- Prototype detects create/modify/rename/delete under a selected root and exposes dropped-event/root-change flags.
- Security-scoped bookmark creation, restoration, stale detection, and repair behavior are demonstrated.
- ADR-002 records FSEvents stream options, debounce ownership, and recovery/rescan rules.

Tasks:

- [x] `R-04.1` Build an FSEvents command-line prototype with copied Sendable event values.
- [x] `R-04.2` Exercise large bursts, root rename/removal, sleep/wake, and inaccessible folders.
- [x] `R-04.3` Prototype bookmark persistence in a minimal GUI harness.
- [x] `R-04.4` Write `docs/adr/002-monitoring-and-folder-access.md`.

**R-05 — Resolve licensing, signing, and sandbox posture (S)**
As the maintainer, I want documented distribution constraints so that implementation and assets do not create avoidable legal or packaging debt.

Acceptance criteria:

- `NOTICE.md` retains required historical notices and identifies new authorship.
- ADR-003 confirms private hardened-runtime distribution, signing approach, sandbox status, and what must change before public distribution.
- Historical visual assets are classified as reusable, replace, or unknown; unknown assets are not shipped.

Tasks:

- [x] `R-05.1` Confirm licence history and last official release evidence; record sources, not legal conclusions.
- [x] `R-05.2` Inventory app icons/images/frameworks and classify their intended treatment.
- [x] `R-05.3` Test an empty hardened-runtime app with local signing.
- [x] `R-05.4` Write `NOTICE.md` and `docs/adr/003-distribution-security.md`.

**R-06 — Establish project governance and memory (S)**
As the maintainer, I want durable principles and linked records so that decisions, failures, fixes, and discoveries survive long-running work.

Acceptance criteria:

- A versioned constitution defines non-negotiable engineering, security, accessibility, evidence, scope, attribution, and governance rules.
- Issues, reusable solutions, learnings, ADRs, and sprint reviews have stable IDs, templates, and linking conventions.
- Every executable task in this plan has a checkbox and stable ID.

Tasks:

- [x] `R-06.1` Ratify constitution v1.0.0 at `.specify/memory/constitution.md`.
- [x] `R-06.2` Add issue, solution, and learning ledgers under `docs/project-ledger/`.
- [x] `R-06.3` Add ADR and sprint-review templates.
- [x] `R-06.4` Define checkbox states, evidence rules, and stable cross-linking conventions in this plan.
- [x] `R-06.5` Verify every current executable task has a checkbox and unique task ID.

**Sprint 0 exit gate:** R-01 through R-06 are complete; ADR-001/002/003 are accepted; browser and protocol fixtures run locally; no architecture-blocking unknown remains. If Network.framework fails, the selected fallback is proven before Sprint 1.

### Phase 1 — Modern foundation and project lifecycle

**Outcome:** a clean arm64 app can add projects, retain access, display status, and run a testable service core.

**Completion evidence (2026-07-13):** `specs/002-modern-foundation/tasks.md` is the executable record. The final `scripts/verify-modern.sh` run passed 27 core tests, 6 app tests, 5 lifecycle/recovery UI tests, a real disposable bookmark round trip, Debug/Release builds, arm64/macOS 15 and Hardened Runtime checks, documentation/version checks, and tracked build-product and agent-runtime privacy gates. The Phase 1 readiness verdict is recorded in `docs/modernization/sprint-reviews/sprint-1.md`.

#### Sprint 1 — Build system and domain foundation

**Sprint goal:** launch a clean Swift 6.2 application and establish package/test boundaries with no legacy runtime dependencies.

**F-01 — Create the modern project (M)**
As a contributor, I want a deterministic modern build so that every later slice starts from a trusted baseline.

Acceptance criteria:

- Debug and Release build arm64-only for macOS 15+ with Swift 6.2 strict concurrency.
- App and local package tests run from one documented `xcodebuild` command with warnings treated as errors.
- Dependency inspection shows no CocoaPods, embedded Node, Ruby, CoffeeScript, or third-party package.

Tasks:

- [x] `F-01.1` Create `ModernLiveReload/LiveReload.xcodeproj` with SwiftUI app and UI-test targets.
- [x] `F-01.2` Create local `Packages/LiveReloadCore` targets for model, monitoring, protocol, build, and test support.
- [x] `F-01.3` Configure arm64, macOS 15, hardened runtime, bundle IDs, signing, strict concurrency, and warning policy.
- [x] `F-01.4` Add shared schemes and `scripts/verify-modern.sh`.
- [x] `F-01.5` Add repository documentation for building only the modern target.

**F-02 — Define the domain model (M)**
As the app, I need versioned project configuration so that persisted user choices remain migratable.

Acceptance criteria:

- Models are Codable, Sendable, versioned, and independent of SwiftUI/AppKit.
- Build command, ignore rules, monitoring state, bookmark metadata, and per-project identity are represented.
- Round-trip, defaults, invalid input, and future-version rejection tests pass.

Tasks:

- [x] `F-02.1` Define `ProjectConfiguration`, `BuildConfiguration`, `IgnoreRule`, `MonitoringState`, and `ActivityEvent`.
- [x] `F-02.2` Define schema envelope/version and migration protocol.
- [x] `F-02.3` Add fixtures and unit tests for all model states.
- [x] `F-02.4` Document invariants and identifier/path semantics.

**F-03 — Establish diagnostics (S)**
As a user and maintainer, I want structured diagnostics so that failures are actionable without attaching a debugger.

Acceptance criteria:

- OSLog categories cover app, storage, monitoring, network, build, and pipeline.
- In-app events use a bounded, redacted representation with stable severity and category.
- Tests prove the history limit and path redaction policy.

Tasks:

- [x] `F-03.1` Define logging categories and `ActivityEvent` mapping.
- [x] `F-03.2` Implement bounded activity storage.
- [x] `F-03.3` Add privacy/redaction and capacity tests.

**Sprint 1 exit gate:** clean build and all tests pass from Terminal; the empty app launches natively as arm64; the model package has no UI dependencies.

#### Sprint 2 — Persistence, folder access, and first usable UI

**Sprint goal:** a user can add a project, restart the app, and recover folder access failures.

**P-01 — Persist projects safely (L)**
As a user, I want my project list restored after relaunch so that setup is one-time.

Acceptance criteria:

- Storage is atomic, versioned, and located under Application Support.
- Missing/corrupt files yield defaults plus a visible diagnostic; the bad file is preserved for diagnosis.
- Duplicate folders are rejected using normalized file identity rather than display-name comparison.

Tasks:

- [x] `P-01.1` Implement injectable `ProjectStore` actor and atomic file replacement.
- [x] `P-01.2` Implement schema migration entry point and corrupt-store recovery.
- [x] `P-01.3` Implement normalized duplicate detection.
- [x] `P-01.4` Add temporary-directory integration tests.

**P-02 — Manage security-scoped bookmarks (M)**
As a user, I want the app to regain selected-folder access and guide me when permission is stale.

Acceptance criteria:

- Bookmark create/resolve/start/stop access lifecycle is balanced and tested behind an adapter.
- Stale or failed bookmarks produce `needsRepair`, not project deletion.
- Repairing a project retains its ID and settings.

Tasks:

- [x] `P-02.1` Implement `FolderAccessProvider` abstraction and production bookmark adapter.
- [x] `P-02.2` Add stale/failure/replacement tests using a fake provider.
- [x] `P-02.3` Add integration coverage for a real selected temporary folder.

**P-03 — Build project-list UI (M)**
As a user, I want to add, inspect, rename, enable, repair, and remove watched projects.

Acceptance criteria:

- First-run empty state explains the app and has a keyboard-accessible add action.
- `NSOpenPanel` adds a folder; destructive removal requires confirmation but does not delete disk content.
- Permission and missing-folder states provide a repair action.
- Core flow passes XCUITest with accessibility identifiers.

Tasks:

- [x] `P-03.1` Implement `LiveReloadApp`, `AppModel`, and `NavigationSplitView` shell.
- [x] `P-03.2` Implement project list/detail/empty states and open-panel bridge.
- [x] `P-03.3` Add rename, enable, repair, and remove flows.
- [x] `P-03.4` Add keyboard, VoiceOver labels/order, light/dark mode checks, and UI tests.

**Sprint 2 exit gate:** PASS — add/restart/restore/repair/remove works in a Release build; persistence and UI tests pass; monitoring, reload, and build execution remain deferred and are not represented as complete.

### Phase 2 — Minimum useful reload loop

**Outcome:** a real file change in a selected project causes a standards-compatible reload message in a connected modern browser.

**Implementation evidence (2026-07-14):** `specs/003-reload-loop/tasks.md` is the executable record. Phase 2 now has actor-owned FSEvents monitoring, bounded filtering/batching, an owned loopback protocol-7/RFC 6455 server, classified pipeline delivery, event-driven app composition, accessible runtime/recovery UI, raw-server and production Safari/Chromium compatibility coverage. Runtime activity is deliberately not persisted. Build execution, automatic monitoring restoration, browser-client/extension bundling, URL override, broad-network access, App Sandbox, and public distribution remain assigned to later specifications.

#### Sprint 3 — Reliable filesystem monitoring

**Sprint goal:** convert FSEvents into deterministic, filtered, debounced project change batches.

**M-01 — Monitor project roots (L)**
As a user, I want file changes detected reliably without high idle resource usage.

Acceptance criteria:

- Create/modify/rename/delete produce normalized Sendable events for enabled projects only.
- Root removal, unmount, and dropped-event flags transition to explicit recovery states.
- Start/stop is idempotent and releases streams and folder access.

Tasks:

- [x] `M-01.1` Implement `FileEventSource` protocol and FSEvents adapter per ADR-002.
- [x] `M-01.2` Implement `ProjectMonitor` actor lifecycle and event normalization.
- [x] `M-01.3` Handle dropped-event/root-change flags with explicit recovery/restart policy.
- [x] `M-01.4` Add fake-source unit tests and workspace-backed disposable-directory integration tests.

**M-02 — Filter and debounce changes (M)**
As a user, I want noisy/generated files ignored and save bursts collapsed into one action.

Acceptance criteria:

- Defaults ignore VCS, common dependency/build directories, and editor temporary files.
- User rules have documented glob/path semantics and can be tested before saving.
- A burst produces one ordered, deduplicated batch inside the configured 100–500 ms window.

Tasks:

- [x] `M-02.1` Specify ignore syntax and precedence in the Phase 2 ignore-rule contract.
- [x] `M-02.2` Implement path normalization, default filters, and user rules.
- [x] `M-02.3` Implement injectable-clock debounce and deduplication.
- [x] `M-02.4` Add boundary, Unicode, hidden-file, symlink, and 10,000-event tests.

**M-03 — Surface monitoring state (S)**
As a user, I want visible monitoring status and recent file events so that I can trust the app.

Tasks:

- [x] `M-03.1` Bind stopped/starting/watching/recovering/failed states to project UI.
- [x] `M-03.2` Add start/stop/retry controls and bounded file-event activity rows.
- [x] `M-03.3` Add app and UI tests using injected monitor events.

**Sprint 3 exit gate:** PASS — real workspace-backed lifecycle/recovery tests and injected UI regressions pass; the 30-second warm-up plus 300-sample idle probe recorded 0.0126% mean and 0.0251% peak CPU, and repeated monitor/server cleanup passed. Evidence: `docs/modernization/evidence/reload-loop/idle-resources.md`.

#### Sprint 4 — Protocol server and browser compatibility

**Sprint goal:** complete the first vertical slice from a disk change to a browser reload.

**W-01 — Implement protocol 7 (M)**
As a browser client, I want a valid LiveReload handshake and reload message so that existing integrations work unchanged.

Acceptance criteria:

- Pure parser/encoder rejects malformed or unsupported messages without crashing.
- Golden fixtures cover hello negotiation, reload, alert if retained, unknown commands, and field defaults.
- All protocol values crossing actors are Sendable.

Tasks:

- [x] `W-01.1` Define typed client/server messages and validation errors.
- [x] `W-01.2` Implement JSON decoding/encoding and negotiation state machine.
- [x] `W-01.3` Run golden fixtures shared with Sprint 0 browser research.

**W-02 — Serve browser connections (L)**
As a user, I want browsers to connect locally and reconnect safely.

Acceptance criteria:

- Server binds loopback by default, validates `/livereload`, supports multiple clients, and exposes client count.
- Port collision, malformed client, and disconnect produce bounded diagnostics without taking down other clients.
- Stop closes listener and clients; restart succeeds on the same port.

Tasks:

- [x] `W-02.1` Implement `ReloadServer` and isolated session ownership per ADR-001.
- [x] `W-02.2` Add lifecycle, multiple-client, invalid-handshake, disconnect, and port-conflict integration tests.
- [x] `W-02.3` Add manual-reload API and connection-status events.

**W-03 — Connect monitoring to reload (M)**
As a user, I want saving a source file to refresh my browser automatically.

Acceptance criteria:

- No-build project changes broadcast exactly one reload batch.
- CSS changes request live CSS; HTML/JS/unknown types request safe page reload behavior.
- Independent Safari and Chromium fixtures demonstrate the accepted behavior matrix.

Tasks:

- [x] `W-03.1` Implement initial `ProjectPipeline` actor for monitor → reload.
- [x] `W-03.2` Implement reload classification and path mapping.
- [x] `W-03.3` Add end-to-end production-server browser test harness and sanitized evidence.
- [x] `W-03.4` Update browser compatibility documentation with actual Safari and Chromium results.

**Sprint 4 exit gate / Milestone 1 preview:** PASS — protocol, socket, pipeline, recovery, app/UI, and production-browser coverage proves real workspace CSS and HTML changes produce classified delivery to current Safari and Chromium while a malformed third client is isolated. T001–T039 and EV-P2-001–EV-P2-012 are complete with no unresolved critical/high analysis finding. Evidence: `docs/modernization/evidence/reload-loop/browser-compatibility-2026-07-14.md`, `docs/modernization/evidence/reload-loop/final-cross-artifact-analysis.md`, and `docs/modernization/sprint-reviews/sprint-2.md`.

### Phase 3 — Developer workflow and daily usability

**Outcome:** projects can build before reload, failures are diagnosable, and the app works comfortably from the menu bar.

#### Sprint 5 — Safe build execution

**Sprint goal:** run optional project build commands predictably without overlapping work or shell injection.

**B-01 — Configure structured commands (M)**
As a user, I want to choose an executable, arguments, working directory, and environment additions without hand-editing configuration files.

Acceptance criteria:

- Default mode executes an executable URL plus argument array and never invokes `/bin/sh`.
- UI validates executable access, working directory, timeout, and environment keys before saving.
- An explicitly labelled shell mode, if added later, remains deferred and absent from v1.

Tasks:

- [ ] `B-01.1` Finalize `BuildConfiguration` validation and bookmark needs.
- [ ] `B-01.2` Build command editor with executable picker and argument list.
- [ ] `B-01.3` Add validation and persistence tests.

**B-02 — Execute and observe builds (L)**
As a user, I want output, exit status, timeout, and cancellation visible so that build failures are actionable.

Acceptance criteria:

- stdout/stderr stream incrementally and remain bounded.
- Success, nonzero exit, launch failure, timeout, and cancellation are distinct results.
- Child process terminates when monitoring or the app stops; tests leave no orphan process.

Tasks:

- [ ] `B-02.1` Implement `BuildRunner` actor around `Process` and `Pipe`.
- [ ] `B-02.2` Implement timeout and graceful-then-forced cancellation.
- [ ] `B-02.3` Add fixture executables and integration tests for every result.
- [ ] `B-02.4` Add build output/result activity views.

**B-03 — Serialize build and reload pipeline (M)**
As a user, I want rapid saves to produce predictable builds and reload only valid output.

Acceptance criteria:

- A project has at most one active build.
- Events during a build schedule exactly one follow-up build using the accumulated batch.
- Reload occurs immediately without a build, after exit 0 with a build, and never after failure/cancellation.

Tasks:

- [ ] `B-03.1` Extend `ProjectPipeline` state machine and injectable dependencies.
- [ ] `B-03.2` Add concurrency, coalescing, cancellation, and reload-suppression tests.
- [ ] `B-03.3` Add a visible queued/running/failed/succeeded state.

**Sprint 5 exit gate:** a real fixture project builds and reloads; a failing build visibly suppresses reload; stress tests prove no overlap or orphan process.

#### Sprint 6 — Menu bar, settings, and recovery polish

**Sprint goal:** make the app comfortable and trustworthy during a full development day.

**U-01 — Deliver menu-bar workflow (M)**
As a user, I want essential controls available without keeping a window open.

Acceptance criteria:

- Menu shows overall health, active projects, connected browsers, pause/resume, manual reload, open window, and quit.
- Icon/status changes are understandable without relying on color alone.
- Commands have keyboard equivalents and VoiceOver labels.

Tasks:

- [ ] `U-01.1` Implement `MenuBarExtra` and shared command routing.
- [ ] `U-01.2` Design healthy/paused/building/error status presentation.
- [ ] `U-01.3` Add menu command and accessibility UI tests.

**U-02 — Complete settings and ignore UX (M)**
As a user, I want to configure port, debounce, default ignores, history, and launch behavior safely.

Tasks:

- [ ] `U-02.1` Define global settings model and defaults.
- [ ] `U-02.2` Implement port/debounce/history/default-ignore controls with validation.
- [ ] `U-02.3` Implement per-project ignore editor with match preview.
- [ ] `U-02.4` Add reset/default/migration tests.

**U-03 — Recover from expected failures (M)**
As a user, I want the app to explain and recover from lost folders, occupied ports, sleep/wake, and failed builds.

Acceptance criteria:

- Every known recoverable error offers a direct action or clear instruction.
- Sleep/wake and network changes do not duplicate monitors/listeners.
- Activity history provides enough context without exposing sensitive environment values.

Tasks:

- [ ] `U-03.1` Add recovery coordinators for folder, server, and monitor lifecycle.
- [ ] `U-03.2` Observe workspace sleep/wake and network/path transitions where needed.
- [ ] `U-03.3` Add injected-error UI tests and real lifecycle integration tests.

**U-04 — Launch at login (S, stretch)**

Tasks:

- [ ] `U-04.1` Research current `SMAppService` requirements from Apple documentation.
- [ ] `U-04.2` Implement opt-in launch at login and state reconciliation.
- [ ] `U-04.3` Verify enable/disable across app updates and document limitations.

**Sprint 6 exit gate / Milestone 2 preview:** the main window can remain closed during normal use; pause/resume, errors, recovery, settings, and accessibility smoke tests pass.

### Phase 4 — Quality, security, and private preview

**Outcome:** produce a measured, signed, documented arm64 preview suitable for ongoing personal use.

#### Sprint 7 — Compatibility, resilience, and performance

**Sprint goal:** convert non-functional requirements into repeatable evidence and fix any threshold failures.

**Q-01 — Expand compatibility coverage (M)**

Tasks:

- [ ] `Q-01.1` Test Safari and current Chromium with script-tag and extension-based connection where available.
- [ ] `Q-01.2` Verify CSS, images, HTML, JavaScript, source maps, Unicode paths, spaces, and symlinks.
- [ ] `Q-01.3` Publish the supported/unsupported matrix and turn failures into tests or documented limits.

**Q-02 — Stress and lifecycle testing (L)**

Acceptance criteria:

- 10,000 synthetic events stay memory-bounded and produce one pipeline run per project/debounce interval.
- A 60-minute soak has no crash, orphan process, duplicate listener, or lost monitoring after sleep/wake.
- Rapid enable/disable, project removal during build, root move, and occupied port remain recoverable.

Tasks:

- [ ] `Q-02.1` Build deterministic stress generators and lifecycle scenarios.
- [ ] `Q-02.2` Run Thread Sanitizer and Address Sanitizer in separate supported configurations.
- [ ] `Q-02.3` Run 60-minute soak and archive OSLog/test artifacts.
- [ ] `Q-02.4` Fix failures and add regression tests before repeating the gate.

**Q-03 — Measure performance (M)**

Acceptance criteria:

- Idle CPU is below 1% over five minutes with two projects and one browser.
- File-event-to-WebSocket-message latency is below 500 ms at p95 without a build.
- Activity and process output buffers remain within documented memory limits.

Tasks:

- [ ] `Q-03.1` Define reproducible Instruments/CLI measurement procedure.
- [ ] `Q-03.2` Capture baseline CPU, memory, wakeups, and latency.
- [ ] `Q-03.3` Profile and fix threshold misses; retain before/after evidence.

**Q-04 — Security review (M)**

Tasks:

- [ ] `Q-04.1` Threat-model local network exposure, WebSocket inputs, file paths, bookmarks, process execution, logs, and persisted configuration.
- [ ] `Q-04.2` Fuzz or property-test protocol decoding and path/ignore parsing.
- [ ] `Q-04.3` Verify loopback binding, input limits, environment redaction, and process cancellation.
- [ ] `Q-04.4` Document accepted risks and revisit ADR-003.

**Sprint 7 exit gate:** all compatibility, stress, performance, sanitizer, and security thresholds pass with saved evidence; unresolved findings are release blockers or explicitly accepted with rationale.

#### Sprint 8 — Release candidate and private preview

**Sprint goal:** ship a reproducible private arm64 build with installation and recovery documentation.

**D-01 — Finish product and attribution assets (M)**

Tasks:

- [ ] `D-01.1` Create an original modern icon and verify all shipped assets have clear provenance.
- [ ] `D-01.2` Finalize About, acknowledgements, licence, privacy, and modernization notices.
- [ ] `D-01.3` Audit user-facing copy, accessibility, appearance modes, and localization readiness.

**D-02 — Package and verify Release candidate (L)**

Acceptance criteria:

- Archive contains only arm64 executable code and required resources.
- Hardened-runtime signature passes `codesign --verify --deep --strict`.
- A clean user account completes install → add project → connect browser → change → build → reload.

Tasks:

- [ ] `D-02.1` Configure archive/export settings and versioning.
- [ ] `D-02.2` Build Release archive and inspect architecture, linked libraries, entitlements, and embedded content.
- [ ] `D-02.3` Run signing/Gatekeeper checks appropriate to the chosen local identity.
- [ ] `D-02.4` Run clean-account smoke test and record the checklist.

**D-03 — Publish private documentation (M)**

Tasks:

- [ ] `D-03.1` Write installation, first-run, browser connection, build setup, ignores, troubleshooting, and uninstall guides.
- [ ] `D-03.2` Publish architecture, ADR index, test procedure, and release checklist for future maintenance.
- [ ] `D-03.3` List known limitations and deferred features without implying compatibility that was not tested.
- [ ] `D-03.4` Tag the private preview and preserve build/test evidence; do not publish binaries publicly without a separate distribution decision.

**Sprint 8 exit gate / Version 1 done:** every Definition of Done item passes, the private preview runs from a clean account, and the repository tag identifies the exact verified source.

## Dependency Order and Critical Path

```text
R-01/R-02 ──► R-03 ──► F-01 ──► W-01/W-02 ──┐
     R-04 ──► F-02 ──► P-01/P-02 ──► M-01/M-02 ──► W-03 ──► B-03 ──► Q-02 ──► D-02
     R-05 ──► F-01 ────────────────────────────► B-01/B-02 ──► Q-04 ──► D-01/D-03
```

- The critical risk path is WebSocket feasibility → clean foundation → monitoring → protocol server → end-to-end loop.
- UI work may proceed against fakes after F-02, but no UI story is complete until its real service integration passes.
- Build commands start only after the no-build reload loop is proven in Sprint 4.
- Packaging starts only after resilience, performance, and security gates pass.

## Sprint Review Checklist

At the end of every sprint:

1. Run the sprint's unit, integration, and UI targets from a clean derived-data directory.
2. Build Release with warnings treated as errors and inspect new warnings or entitlements.
3. Demonstrate the sprint goal using a fixture project, not mocks alone.
4. Update behavior inventory, ADRs, compatibility matrix, and known risks.
5. Update `issues.md`, `solutions.md`, and `learnings.md`; link new entries to their task and evidence.
6. Check compliance with the current constitution and record any temporary exception with an expiry.
7. Review `git diff` for copied legacy implementation, accidentally committed build products, credentials, absolute local paths, and bundled obsolete binaries.
8. Record the exact commands and results in `docs/modernization/sprint-reviews/sprint-N.md`.
9. Re-plan unfinished tasks; do not silently roll an incomplete story forward as “done.”

## Technical Workstreams

### 1. Preserve the baseline and specify observable behavior

1. Tag or record the untouched fork baseline before implementation.
2. Add `docs/modernization/behavior-inventory.md` covering project creation, start/stop, ignore semantics, protocol handshake, CSS/image/page reload messages, build success/failure, persistence, and error states.
3. Add protocol fixtures derived from the published protocol behavior rather than copying obsolete backend code.
4. Add `NOTICE.md` retaining the existing copyright/licence notice and distinguishing the modern rewrite.

Acceptance gate: every v1 requirement has at least one named unit, integration, or UI test before implementation begins.

### 2. Establish a clean modern build

1. Create the new Xcode project and local `LiveReloadCore` package.
2. Set Swift 6.2 strict concurrency, macOS 15.0, arm64-only supported architectures, hardened runtime, automatic local signing, and zero third-party dependencies.
3. Add app, package-test, and UI-test schemes plus a command-line `xcodebuild` verification script.
4. Add CI for arm64 macOS runners when available; otherwise retain a documented local release gate.

Acceptance gate: a clean checkout builds with warnings treated as errors and all empty test targets execute successfully on Apple silicon.

### 3. Implement project persistence and folder access

1. Define stable, versioned `ProjectConfiguration`, `BuildConfiguration`, and `IgnoreRule` models.
2. Implement add/remove/rename/enable operations and bookmark persistence.
3. Detect stale or inaccessible bookmarks and present a repair flow instead of silently dropping projects.
4. Unit-test schema round trips, migration hooks, corrupt storage, duplicates, and stale bookmarks.

Acceptance gate: selected projects survive application restart; revoked access produces a recoverable UI state.

### 4. Implement filesystem monitoring

1. Wrap FSEvents behind an injectable `FileEventSource` protocol.
2. Normalize paths and filter `.git`, dependency/build directories, editor temporaries, and user ignore patterns.
3. Debounce event bursts per project and detect root deletion or unmounting.
4. Provide deterministic fake-event tests and integration tests using temporary directories.

Acceptance gate: creating, modifying, renaming, and deleting files produces one normalized change batch within the configured debounce window, with ignored files producing none.

### 5. Implement the LiveReload server and protocol

1. Implement protocol 7 handshake parsing/validation as pure Sendable types.
2. Build the local TCP/WebSocket server using Network.framework, binding to loopback by default and making port conflicts visible.
3. Track client lifecycle and broadcast reload messages with path, liveCSS, liveImg, and reload-delay fields.
4. Serve `livereload.js` only if needed for compatibility; prefer compatibility with existing extensions first.
5. Add raw-socket integration tests for valid/invalid handshakes, multiple clients, disconnects, port conflicts, and reload broadcast.

Acceptance gate: an independent browser fixture connects on `ws://127.0.0.1:35729/livereload`, completes protocol 7 negotiation, and receives a valid reload command for a changed file.

### 6. Build the project pipeline and command runner

1. Connect debounced monitor events to `ProjectPipeline`.
2. Implement direct executable-plus-arguments invocation with explicit working directory and a minimal inherited environment.
3. Stream stdout/stderr into bounded activity records, add cancellation and timeout, and terminate child processes when monitoring stops.
4. Coalesce changes that arrive during a build and perform at most one follow-up build.
5. Broadcast reload immediately when no build is configured, or only after exit status 0 when one is configured.

Acceptance gate: tests prove no overlapping builds, failure suppresses reload, cancellation removes the child process, and a change during a build results in exactly one follow-up run.

### 7. Build the native UI

1. Implement `MenuBarExtra` for status, active project count, connected browsers, start/stop, manual reload, open window, and quit.
2. Implement a `NavigationSplitView` project window with folder selection, monitoring toggle, build command editor, ignores, connection status, and activity log.
3. Add clear empty, loading, permission-loss, port-conflict, build-failure, and folder-missing states.
4. Add accessibility labels, keyboard navigation, VoiceOver order, reduced-motion behavior, light/dark mode, and Dynamic Type-compatible layouts.
5. Add launch-at-login through `SMAppService` only after the core lifecycle is stable.

Acceptance gate: UI tests add a fixture project, toggle monitoring, show a simulated connection, expose a file event/build/reload sequence, and recover from an injected error without restarting.

### 8. End-to-end compatibility and resilience

1. Create a local HTML fixture that loads the maintained LiveReload client or connects directly using protocol 7.
2. Verify CSS-only refresh where supported and full-page refresh for HTML/JS/unknown files.
3. Stress-test large event bursts, rapid project toggling, sleep/wake, network changes, folder moves, port occupation, and application relaunch.
4. Measure idle CPU, idle memory, event-to-message latency, and activity-history bounds.

Acceptance gate:

- Idle CPU remains below 1% after a five-minute sample with two watched projects and one connected browser.
- Event-to-WebSocket-message latency is below 500 ms at p95 excluding configured builds.
- A burst of 10,000 synthetic events remains bounded in memory and produces one coalesced pipeline run per project/debounce interval.
- The app completes a 60-minute soak without crash, leaked child process, or loss of monitoring after sleep/wake.

### 9. Package a private preview

1. Add a modern icon and required privacy strings; do not reuse proprietary visual assets without confirming their licence status.
2. Produce an arm64 Release archive with hardened runtime and ad-hoc or Personal Team signing for local use.
3. Run `codesign`, Gatekeeper assessment where applicable, clean-machine launch, and release smoke tests.
4. Document installation, browser connection, folder permissions, build-command configuration, known limitations, and attribution.

Acceptance gate: the archived app launches natively as arm64, persists a project, reconnects a browser, observes a file change, runs the configured build, and triggers reload on a clean user account.

## Verification Matrix

| Layer | Proof |
|---|---|
| Model | Codable round trips, schema-version tests, corrupt-data recovery |
| Monitoring | Fake source unit tests plus temporary-directory FSEvents integration tests |
| Protocol | Parser fixtures, malformed input, raw WebSocket handshake and broadcast tests |
| Build | Success/failure/output/timeout/cancellation/concurrency tests using fixture executables |
| Pipeline | Deterministic actor tests for debounce, coalescing, stop, and follow-up builds |
| UI | XCUITest for first run, project management, status, activity, errors, accessibility identifiers |
| End to end | Local browser fixture observes CSS and page reload behavior |
| Release | `xcodebuild test`, Release archive, `file`, `codesign --verify --deep --strict`, launch smoke test |

## Risks and Mitigations

- **Network.framework WebSocket server limitations:** prototype the listener in phase 5 before UI integration. If server-side framing is unsuitable, implement the small RFC 6455 subset locally rather than adding a dependency prematurely.
- **Sandbox versus arbitrary build tools:** keep v1 private and hardened-runtime enabled but App Sandbox disabled. Design bookmarks and the process boundary so sandbox evaluation can occur later without reworking models.
- **FSEvents coalescing and dropped-event flags:** treat root/history-done/user-dropped/kernel-dropped events explicitly and rescan project state when the stream indicates loss.
- **Swift concurrency and C callbacks:** isolate callback bridging in the monitoring adapter, copy callback data immediately, and cross into actors through Sendable values only.
- **Protocol ambiguity:** use the legacy parser and server tests as behavioral evidence, then validate against an independent current browser client.
- **Scope creep into compilers:** v1 exposes general build commands only. Compiler presets require a later proposal and user evidence.
- **Historical code contamination:** implement new modules from documented behavior and tests; do not mechanically translate old Swift/CoffeeScript files.

## Milestones

1. **Foundation:** clean arm64 Swift 6 build, models, persistence, and project UI shell.
2. **Minimum useful loop:** FSEvents → protocol server → browser reload, no build command.
3. **Developer workflow:** build runner, ignores, logs, recovery states, and launch at login.
4. **Private preview:** compatibility matrix, performance/soak verification, signing, documentation.

Each milestone ends with a runnable app and green tests; no milestone depends on resurrecting the old Node backend or plugin toolchains.

## Definition of Done for Version 1

- All version 1 requirements and acceptance gates above pass on an Apple-silicon Mac.
- `xcodebuild` Debug and Release builds complete with zero warnings.
- Unit, integration, UI, browser-fixture, and release smoke tests pass.
- No Rosetta process, embedded runtime, third-party package, telemetry, updater, or licensing service is present.
- Known limitations and security choices are documented.
- Legacy source remains available as reference, and the new implementation is isolated enough to remove it from future release archives.

## Recommended First Execution Slice

Implement milestones 1 and 2 only: create the modern project, persistence model, one-project UI, FSEvents adapter, protocol handshake, and end-to-end browser fixture. Defer build commands until the core change-to-reload loop is proven. This is the smallest slice that validates all high-risk architectural boundaries.
