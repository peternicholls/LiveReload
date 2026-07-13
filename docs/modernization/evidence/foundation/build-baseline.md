# Modern Build Baseline

Date: 2026-07-13. Host: Apple silicon, Swift 6.2.4, Xcode 26.3-compatible toolchain.

| Gate | Result |
|---|---|
| `swift test --package-path Packages/LiveReloadCore -Xswiftc -warnings-as-errors` | PASS — 27 tests |
| Core Release build with warnings as errors | PASS |
| App Debug build, arm64/macOS 15, warnings as errors | PASS |
| App Release build, arm64/macOS 15, warnings as errors | PASS |
| App/unit/UI test bundle build | PASS — five lifecycle/recovery XCUITests compile and sign |
| Unit target execution | PASS — 6 app tests, 27 core tests |
| UI target execution | PASS — 5 tests, 0 failures |
| Release architecture | PASS — Mach-O arm64 |
| Release signing | PASS — Apple Development signature, Hardened Runtime flag `runtime` |

Generated package and Xcode build directories are ignored. The UI target built, signed, and executed all five scenarios, covering loading, add, relaunch restoration, rename, enabled state, missing-folder repair, corrupt-store recovery, future-version write protection, long labels, reduced motion, confirmed removal, and source-folder preservation through deterministic disposable test dependencies.
