# Modern LiveReload Developer Guide

## Current workflow

1. Start feature work from the active Spec Kit feature branch; the feature `tasks.md` is the execution ledger.
2. Follow the constitution and Phase 0 ADRs. Do not import legacy implementation or add dependencies without recorded justification.
3. Add tests/fixtures before behavior where practical. Run the applicable Debug, Release, unit, integration, UI, privacy, and signing checks before marking a task complete.
4. Update the issue, solution, learning, ADR, sprint-review, guide, changelog, and inclusion-register records affected by the change.
5. Use Lore-format commits. Before release/merge, run the documented verification command and review `VERSIONING.md`, `CHANGELOG.md`, `NOTICE.md`, and `docs/project-ledger/software-inclusions.md`.

## Documentation change checklist

- User-visible flow, error, permission, compatibility, or limitation changed: update `user-guide.md`.
- Build, test, architecture, dependency, signing, or release workflow changed: update this guide.
- New code, package, asset, generator, tool, service, or copied material: update the inclusion register and `NOTICE.md` if required.
- Releasable change: update `CHANGELOG.md` and select/version according to `VERSIONING.md`.

## Phase 1 build and test

Prerequisites are Xcode 26.3 or a compatible Swift 6.2 toolchain, an Apple-silicon Mac, a valid local Apple Development signing identity, and macOS developer mode enabled with `sudo DevToolsSecurity -enable`. From repository root run:

```sh
scripts/verify-modern.sh
```

The command fails on package tests/Release build, app Debug/Release or test build, UI-framework leakage into core, third-party/legacy dependencies, non-arm64 output, deployment below macOS 15, missing Hardened Runtime signing, version mismatch, tracked build products, or missing governance documents. macOS must permit Xcode UI automation for XCUITest execution; absence of that host permission is a blocking verification failure, not a skipped pass.

For focused core work use `swift test --package-path Packages/LiveReloadCore -Xswiftc -warnings-as-errors`. The package owns models, persistence, folder-access contracts/fakes, and diagnostics. Persisted models reapply constructor invariants during decoding. `ProjectStore` preflights the schema header, owns field-level mutations, and write-protects sources that are newer or could not be preserved; the app must handle every `ProjectStoreLoadOutcome`. Restored bookmarks pass through `ProjectAccessCoordinator`, which resolves and briefly opens scoped access before recording availability. `AppModel` owns a main-actor `ProjectMutationGate`: acquire it before any project mutation, release it with `defer`, and derive control disabled state from the same gate. AppKit is limited to `FolderPicker` and the production bookmark adapter; SwiftUI/Observation/OSLog stay in the app target. `ModernLiveReload/Version.xcconfig` is the single version source.
