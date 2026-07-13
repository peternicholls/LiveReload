# Modern Target Verification Matrix

| Gate | Required command/evidence | Failure rule |
|---|---|---|
| Core Debug/Release | `swift test` and `swift build -c release` with warnings as errors | Any warning/failure blocks |
| App Debug/Release | `xcodebuild` shared scheme for both configurations | Any warning/failure blocks |
| Unit/UI tests | Shared scheme test action | Missing/skipped target blocks |
| Architecture/deployment | `file`, `lipo`, and build settings inspection | Non-arm64 or floor below macOS 15 blocks |
| Signing | `codesign --verify --strict` and hardened-runtime inspection | Invalid/missing signature blocks |
| Clean-account smoke | documented disposable folder/account walkthrough | Missing evidence blocks Phase 1 |
| Dependency/core boundary | manifest/import scans and resolved dependency inventory | Prohibited dependency/import blocks |
| Documentation | version, changelog, inclusion, NOTICE, and guide checks | Missing review blocks |
