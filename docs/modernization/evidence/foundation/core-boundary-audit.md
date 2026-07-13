# LiveReloadCore Boundary Audit

Command:

```sh
rg -n '^import (SwiftUI|AppKit)$' Packages/LiveReloadCore/Sources Packages/LiveReloadCore/Tests
```

Result on 2026-07-13: PASS, no matches. `scripts/verify-modern.sh` runs the same fail-fast check before building. Core production imports Foundation only; tests import Foundation/Testing and the core module.
