# Research and Design Decisions: Modern Foundation

## Decision summary

| Topic | Decision | Rationale | Evidence / follow-up |
|---|---|---|---|
| Core boundary | Local `LiveReloadCore` Swift package with no SwiftUI/AppKit imports | Domain/persistence logic needs deterministic tests and later service reuse | Constitution II/III; package tests gate Phase 1 |
| App composition | SwiftUI app plus a narrow AppKit folder-picker bridge | SwiftUI is the default; `NSOpenPanel` is platform capability isolated at the edge | Constitution II.2, VI |
| Persistence | Versioned JSON envelope with atomic replacement under Application Support | Small local data set needs inspectable, migratable storage without database dependencies | FR-005–FR-007; project-store contract |
| Folder access | Security-scoped bookmarks behind `FolderAccessProvider` | Preserves least privilege and explicit stale/repair flow | ADR-002; folder-access contract |
| Diagnostics | Bounded `ActivityEvent` history with centralized redaction | Makes local failures actionable without persisting private paths/secrets | Constitution IV.4; activity-events contract |
| Distribution | Private arm64 Hardened Runtime preview; App Sandbox deferred | Matches Phase 0 signing evidence and avoids unsupported build-execution claims | ADR-003 |

## Rejected alternatives

### Persist plain folder paths

Rejected because a plain path cannot prove user-granted access, cannot express stale/denied status, and would undermine the repair model established by ADR-002.

### Use Core Data or SwiftData in Phase 1

Rejected for this phase because a versioned project list is small and has explicit JSON migration/recovery requirements. A lightweight actor-owned store has fewer dependencies and a clearer corrupt-file preservation story. Revisit only if later features need relational queries, conflict resolution, or large history retention.

### Put project state directly in SwiftUI view state

Rejected because lifecycle, persistence, testability, and migration would become tied to rendering. `AppModel` owns presentation state; `LiveReloadCore` owns durable domain state.

### Enable App Sandbox now

Rejected by ADR-003. Folder bookmarks fit the sandbox model, but later loopback/build-service constraints require a separate verified decision.

## Inherited constraints

- The app is arm64-only and targets macOS 15+ with Swift 6.2 strict concurrency.
- Existing historical assets remain excluded; `NOTICE.md` remains part of the modern distribution.
- No Node/Ruby/CoffeeScript/CocoaPods or third-party packages may enter Phase 1 without a new ADR.
- Production FSEvents, WebSocket, protocol, and build-execution code are out of scope; model placeholders must not expose executable behavior.

## Verification decisions

- Models first: fixtures cover round trip, defaults, invalid input, and future schema rejection before store/UI work.
- Services next: fake folder access drives deterministic stale/failure/repair tests; one workspace-backed integration test validates the production adapter boundary.
- UI last: XCUITest uses accessibility identifiers and verifies configuration-only removal, repair, and empty/error states.
- Final evidence includes Debug/Release `xcodebuild`, package tests, architecture inspection, codesign verification, privacy scan, and clean-account smoke procedure.
