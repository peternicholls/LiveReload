# Phase 3 Verification Quickstart

Run from the repository root on an Apple-silicon macOS 15+ host with the supported Xcode/Swift toolchain.

## Focused checks

```sh
swift test --package-path Packages/LiveReloadCore -Xswiftc -warnings-as-errors
xcodebuild -project ModernLiveReload/LiveReload.xcodeproj -scheme LiveReload -configuration Debug -destination 'platform=macOS,arch=arm64' build
xcodebuild -project ModernLiveReload/LiveReload.xcodeproj -scheme LiveReload -configuration Release -destination 'platform=macOS,arch=arm64' build
xcodebuild -project ModernLiveReload/LiveReload.xcodeproj -scheme LiveReload -testPlan LiveReload -configuration Debug -destination 'platform=macOS,arch=arm64' test
```

## Fixture scenarios

1. Save valid and invalid build configurations; restart and verify structured round-trip and prior-value preservation.
2. Run success, launch-failure, nonzero, timeout, run-only/lifecycle cancellation, oversized-output, and descendant-process fixture scenarios; verify classifications, exact 1 MiB/16 KiB/4 KiB caps, and no orphan process-group member.
3. Generate at least 10,000 file events while a build runs; verify one active run, one coalesced follow-up after every ordinary terminal result, no follow-up after lifecycle cancellation, and no reload after unsuccessful results.
4. Run with no build configured; verify the Phase 2 immediate reload path remains unchanged.
5. While a build is active and pending changes exist, invoke **Reload Now**; verify one immediate broadcast and no cancellation, consumption, or reordering of build work.
6. Cancel an active descendant-spawning fixture; verify graceful termination escalates after at most 2 seconds, cancellation emits no reload, and exactly one pending follow-up starts when present.
7. Close the main window; exercise menu-bar health, pause/resume, **Reload Now**, both launch-presentation settings, validation/reset, accessibility labels, and recovery actions.
8. Inject folder loss, occupied port, sleep/wake, network/path transition, and project removal; verify unrelated projects continue and recovery owns no duplicate listener, monitor, process group, or pending batch.
9. Fill two active runs to the output cap and retain 500 maximum-size summaries; verify logical diagnostic payload is no more than 5 MiB and every truncation is visible.

## Phase gate

```sh
scripts/verify-modern.sh
```

To refresh rather than consume checked-in Phase 3 and idle evidence:

```sh
RUN_DEVELOPER_WORKFLOW_GATE=1 RUN_IDLE_RESOURCE_GATE=1 scripts/verify-modern.sh
```

The sprint gate is complete only when Debug/Release, package, app/UI, fixture, build-to-browser, process-group cleanup, exact bound, privacy, documentation, inclusion, and relevant performance checks pass; evidence is captured under `docs/modernization/evidence/developer-workflow/` and the sprint review records unfinished work and risks.
