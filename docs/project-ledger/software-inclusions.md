# Software and Licence Inclusion Register

Track everything incorporated into the modern product or required to build/test/release it. This register supports accurate notices and release review; it does not provide legal advice.

## Required fields

| Field | Meaning |
|---|---|
| ID | Stable `INC-NNN` identifier; never reused |
| Status | proposed, approved, excluded, removed, or needs-verification |
| Type | system framework, package, copied source, generated source, asset, tool, service, or legacy reference |
| Origin/version | Authoritative source and pinned version, commit, checksum, or SDK/tool version |
| Licence evidence | Licence identifier/text location or `needs-verification`; do not infer |
| Usage | Exact target/path and whether production, development, test, or release-only |
| Attribution/distribution | Required notice location, distribution constraints, and review owner/date |

## Register

| ID | Status | Type | Origin/version | Licence evidence | Usage | Attribution/distribution |
|---|---|---|---|---|---|---|
| INC-001 | approved | legacy reference | Original LiveReload repository at merged upstream baseline `af9b5ce8` | Repository notice and licence history summarized in `NOTICE.md` and `docs/modernization/distribution-research.md` | Reference source only; excluded from modern release archive | Retain `NOTICE.md`; do not represent as official affiliation |
| INC-002 | approved | system framework | Apple SDK frameworks selected by the modern Xcode target; exact SDK/Xcode captured per release | Apple platform SDK; no copied framework binary is shipped | Production target: Foundation, CoreServices/FSEvents, SwiftUI, Observation, OSLog, and Darwin sockets; AppKit only via bridge | Record SDK/Xcode in release evidence; review entitlement/distribution impact |
| INC-003 | needs-verification | development tool | Spec Kit/OMX workspace tooling | Tooling licence/provenance must be verified before any redistribution | Development/planning only; never embedded in app/archive | No product notice assumed; exclude from app distribution |
| INC-004 | approved | local package/source | Repository-authored `Packages/LiveReloadCore`, Phases 1–2 | Repository licence/NOTICE applies; no copied source | Production domain, persistence, access, diagnostics, monitoring, protocol-7, RFC 6455 server, pipeline, and tests | Included as source and statically linked product; retain repository NOTICE |
| INC-005 | approved | development tool | Swift 6.2 / Xcode 26.3 toolchain | Apple developer-tool terms; tool binaries are not redistributed | Build and XCTest/Swift Testing only | Record tool version in evidence; exclude DerivedData/build products |
| INC-006 | approved | generated source/metadata | Xcode-generated Info.plist and build metadata from `Version.xcconfig` | Generated from repository configuration | App bundle metadata | Reproducible; no external attribution required |
| INC-007 | excluded | asset | Historical LiveReload artwork | Provenance not re-approved for modern target | No modern target asset catalogue or copied artwork | Must remain excluded until provenance review passes |
| INC-008 | approved | development tool | Host Node.js `v26.5.0`; repository-authored Phase 0/2 browser fixture scripts | Node/tool terms apply to the installed executable; tool binary and packages are not redistributed | Browser compatibility fixture only; no package install, copied client library, production import, or bundle inclusion | Record the executable version in browser evidence; exclude Node and fixture scripts from the app archive |
| INC-009 | approved | development tool | Host Safari/SafariDriver and Google Chrome/Chromium versions captured by each compatibility run | Vendor application/tool terms; browser binaries are not redistributed | Interactive production-server compatibility testing only | Record exact versions in sanitized evidence; do not bundle browser profiles, automation logs, or binaries |

## Operating rules

1. Add or update an entry before introducing an inclusion, including copied snippets, generated code, assets, package managers, CI actions, and external services.
2. Pin enough origin information to reproduce the inclusion. A bare homepage is insufficient.
3. Attach licence text/evidence rather than guessing a licence from reputation or repository location.
4. `needs-verification` or `excluded` items must not enter a release archive. Record the issue, owner, and review date if they affect planned work.
5. At every release/phase gate, reconcile this register with project manifests, source headers, generated artefacts, `NOTICE.md`, `CHANGELOG.md`, and the shipped archive.
