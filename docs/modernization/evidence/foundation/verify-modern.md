# `verify-modern.sh` Evidence

Run date: 2026-07-13.

After removing generated package and Xcode build directories, the foundation `scripts/verify-modern.sh` baseline completed successfully. It passed the core UI-boundary scan, zero-external-dependency inventory, 15 then-current core tests, real disposable bookmark round trip, core Release build, signed app Debug/Release builds, and all four XCUITest scenarios.

The remaining gates also passed: arm64 executable, macOS 15 deployment floor, Hardened Runtime signature, bundle/version metadata, changelog/inclusion/NOTICE/guides, and absence of tracked build products.

Result: **PASS**. The current five UI scenarios completed with zero failures and cover corrupt-store recovery, future-version write protection, first launch through relaunch/removal, missing-folder repair, and long-label/reduced-motion behavior.

Pull-request hardening expanded the suite to 27 core tests, 6 app tests, and 5 XCUITests. The final current-code run passed the core Release build, bookmark boundary, signed app Debug/Release builds, all tests, architecture/deployment/signing checks, documentation checks, tracked-build-product scan, and tracked-agent-runtime privacy gate.

No absolute local paths or signing identity details are retained in this evidence.
