# Modern LiveReload

The modern application targets arm64 macOS 15+ with Swift 6 language mode and complete strict-concurrency checking. It links only the repository-local `LiveReloadCore` package and Apple system frameworks.

Development identifiers use `com.peternicholls.LiveReload.Modern`. The project keeps portable ad-hoc signing placeholders; `scripts/verify-modern.sh` requires a local Apple Development identity and verifies its Hardened Runtime signature. Public distribution remains a separate decision.

Run all supported checks from repository root with `scripts/verify-modern.sh`. Legacy Xcode targets and historical Node/Ruby/CoffeeScript tooling are reference-only and are not build inputs for the modern target.

Direct developer commands:

```sh
swift test --package-path Packages/LiveReloadCore -Xswiftc -warnings-as-errors
xcodebuild -project ModernLiveReload/LiveReload.xcodeproj -scheme LiveReload -configuration Debug -destination 'platform=macOS,arch=arm64' build
xcodebuild -project ModernLiveReload/LiveReload.xcodeproj -scheme LiveReload -configuration Release -destination 'platform=macOS,arch=arm64' build
```

`ModernLiveReload/Version.xcconfig` is the single app marketing/build-version source. The shared `LiveReload` scheme and `LiveReload.xctestplan` define app, unit, and UI test targets.
