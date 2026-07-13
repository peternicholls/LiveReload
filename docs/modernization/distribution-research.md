# Distribution and Security Research

**Tasks:** T045, T049
**Date:** 2026-07-12

## Historical source and licence facts

- The repository's `README.md:10-33` identifies copyright 2012–2015 Andrey Tarantsov, permits modification, and states that the additional conditions are waived and the software is additionally MIT-licensed after two consecutive years without official binary releases.
- `upstream/develop` is commit `af9b5ce8d5cf1f7065b8e70e4ddff8bce6963633`, dated 2016-07-03.
- GitHub reports the upstream repository's latest push as 2016-10-27. Repository metadata was updated later, which is not evidence of a binary release.
- This record states source facts only; it is not legal advice. Private personal use and a private preview remain the planned scope.

## Apple platform findings

- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox) is required for Mac App Store distribution and uses entitlements to limit system/file/network access.
- [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox) identifies Incoming Connections (Server) and Outgoing Connections (Client) as explicit network capabilities.
- [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox) states that persisted security-scoped bookmarks require resolving the bookmark and balancing `startAccessingSecurityScopedResource`/`stopAccessingSecurityScopedResource`; stale bookmarks should be recreated. It also states that user-selected-file access does not allow running programs outside the bundle/container/app-group locations without the executable entitlement.
- [Configuring the hardened runtime](https://developer.apple.com/documentation/xcode/configuring-the-hardened-runtime/) explains that notarization requires Hardened Runtime and that exceptions should be individually justified.

## Decision inputs

| Concern | Phase 0 finding | Consequence |
|---|---|---|
| Private preview | Ad-hoc arm64 hardened-runtime signing is reproducible locally. | Use it for private development only. |
| App Sandbox | It can support bookmarks and a loopback listener with explicit entitlements, but constrains arbitrary developer build tools. | Defer sandbox adoption until the structured build-command feature has a dedicated threat-model/prototype. |
| Browser server | A later sandboxed build would need incoming-server entitlement if it listens. | Keep code loopback-only regardless of entitlement. |
| Folder access | Bookmarks are the persistent least-privilege model. | Use selected-folder bookmarks, stale/repair state, and balanced access calls. |
| Assets | Historical artwork has no separately verified provenance. | Exclude/replace it for modern release builds. |

## Limits

No App Store, notarization, public distribution, or executable-entitlement decision is made in Phase 0.
