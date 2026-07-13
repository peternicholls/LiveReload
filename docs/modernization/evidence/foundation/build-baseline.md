# Modern Build Baseline

Date: 2026-07-13. Host: Apple silicon, Swift 6.2.4, Xcode 26.3-compatible toolchain.

| Gate | Result |
|---|---|
| `swift test --package-path Packages/LiveReloadCore -Xswiftc -warnings-as-errors` | PASS — 23 tests |
| Core Release build with warnings as errors | PASS |
| App Debug build, arm64/macOS 15, warnings as errors | PASS |
| App Release build, arm64/macOS 15, warnings as errors | PASS |
| App/unit/UI test bundle build | PASS — four lifecycle XCUITests compile and sign |
| Unit target execution | PASS — 3 app tests, 23 core tests |
| UI target execution | PASS — 4 baseline tests, 0 failures; post-review rerun host-blocked by an unrelated modal window |
| Release architecture | PASS — Mach-O arm64 |
| Release signing | PASS — Apple Development signature, Hardened Runtime flag `runtime` |

Generated package and Xcode build directories were removed before the final run. The UI target built, signed, and executed all four scenarios, covering loading, add, relaunch restoration, rename, enabled state, missing-folder repair, corrupt-store recovery, long labels, reduced motion, confirmed removal, and source-folder preservation through deterministic disposable test dependencies.
