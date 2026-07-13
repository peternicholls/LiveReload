# Phase 1 Verification Quickstart

This is the acceptance workflow that implementation must make reproducible. It does not authorize production monitoring, protocol serving, or build execution.

## Prerequisites

- Apple-silicon Mac running macOS 15 or newer.
- Xcode 26.3 or compatible newer Swift 6.2 toolchain.
- Development signing identity suitable for a private Hardened Runtime build.
- A disposable local folder for project/access tests; never use a private source tree as a test fixture.

## Expected verification command

Implementation creates `scripts/verify-modern.sh`. From repository root it must:

1. Resolve the modern shared scheme and build Debug with warnings as errors.
2. Build Release with warnings as errors.
3. Run `LiveReloadCore` unit/integration tests and app/UI tests.
4. Inspect the produced app for arm64 architecture and deployment target.
5. Verify local Hardened Runtime signing and report only redacted diagnostics.

The script exits non-zero on any failure and does not silently skip unavailable test targets.

## Acceptance walkthrough

1. Launch the empty app and verify the accessible empty-state add action.
2. Add a disposable folder; rename it and change enabled state.
3. Relaunch and verify stable identity/settings restored once.
4. Attempt to add the same folder again and verify duplicate rejection.
5. Use the fake provider/UI test to enter repair-required state; repair with a replacement folder and confirm identity/settings persist.
6. Remove the project and confirm its folder still exists on disk.
7. Trigger a recoverable store/access failure and verify bounded redacted activity output.
8. Review the Sprint 1/2 evidence, ledgers, and task checkboxes before phase closure.

## Required artifacts before Phase 2

- Passing `scripts/verify-modern.sh` output captured in Sprint 1/2 review.
- Core model/store/access/diagnostics test evidence and UI-test evidence.
- arm64 and Hardened Runtime inspection evidence.
- Privacy scan confirming no credentials, private source contents, or absolute local paths in new ledgers/evidence.
- Updated issue, solution, learning, ADR, and sprint-review records where discovery produced durable knowledge.
