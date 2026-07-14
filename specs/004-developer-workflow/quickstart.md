# Phase 3 Verification Quickstart

Run from the repository root on an Apple-silicon macOS 15+ host with the supported Xcode/Swift toolchain.

## Focused checks

```sh
swift test --package-path Packages/LiveReloadCore -Xswiftc -warnings-as-errors
xcodebuild -project ModernLiveReload/LiveReload.xcodeproj -scheme LiveReload -configuration Debug -destination 'platform=macOS,arch=arm64' build
xcodebuild -project ModernLiveReload/LiveReload.xcodeproj -scheme LiveReload -configuration Release -destination 'platform=macOS,arch=arm64' build
```

## Fixture scenarios

1. Save valid and invalid build configurations; restart and verify structured round-trip and prior-value preservation.
2. Run success, launch-failure, nonzero, timeout, cancellation, and oversized-output fixture executables; verify classifications, bounded output, and no orphan process.
3. Generate at least 10,000 file events while a build runs; verify one active run, one coalesced follow-up, and no reload after unsuccessful results.
4. Run with no build configured; verify the Phase 2 immediate reload path remains unchanged.
5. Close the main window; exercise menu-bar health, pause/resume, manual reload, settings, accessibility labels, and recovery actions.
6. Inject folder loss, occupied port, sleep/wake/path transition, and project removal; verify unrelated projects continue and recovery owns no duplicate resource.

## Phase gate

```sh
scripts/verify-modern.sh
```

The sprint gate is complete only when Debug/Release, package, app/UI, fixture, privacy, documentation, inclusion, and relevant performance checks pass; evidence is captured under `docs/modernization/evidence/developer-workflow/` and the sprint review records unfinished work and risks.
