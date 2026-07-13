# Modern Dependency Inventory

`swift package --package-path Packages/LiveReloadCore show-dependencies --format json` reports `LiveReloadCore` with zero dependencies. The Xcode project references one repository-local package product and Apple system frameworks only.

Fail-fast manifest scans found no third-party URL package, CocoaPods input, Node.js, Ruby, or CoffeeScript runtime in the modern package/project manifests. Historical repository targets remain reference-only and are not modern build inputs.

Result on 2026-07-13: PASS.
