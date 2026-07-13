# `verify-modern.sh` Evidence

Run date: 2026-07-13.

After removing generated package and Xcode build directories, the foundation `scripts/verify-modern.sh` baseline completed successfully. It passed the core UI-boundary scan, zero-external-dependency inventory, 15 then-current core tests, real disposable bookmark round trip, core Release build, signed app Debug/Release builds, and all four XCUITest scenarios.

The remaining gates also passed: arm64 executable, macOS 15 deployment floor, Hardened Runtime signature, bundle/version metadata, changelog/inclusion/NOTICE/guides, and absence of tracked build products.

Result: **PASS**. The four UI scenarios completed with zero failures and cover corrupt-store recovery, first launch through relaunch/removal, missing-folder repair, and long-label/reduced-motion behavior.

Post-review hardening added eight core regressions and app coverage for restored access, selection retention, and mutation gating. The 23-test core suite, core Release build, bookmark boundary, signed app Debug/Release builds, and all four app unit tests pass. A full XCUITest rerun was attempted, but a modal window from another host application blocked XCTest pointer-event interruption checks and the 120-second harness stopped the run. No current-code UI pass is claimed from that blocked rerun.

No absolute local paths or signing identity details are retained in this evidence.
