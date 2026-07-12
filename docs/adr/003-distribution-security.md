# ADR-003: Ship private hardened-runtime previews; defer App Sandbox and public distribution

- Status: accepted
- Date: 2026-07-12
- Deciders: Phase 0 maintainer
- Related tasks/issues: T045–T050, AST-001–AST-005
- Supersedes: none

## Context

Version 1 is a personal modern macOS rewrite that must watch user-selected folders, expose a loopback reload server, and later run structured user-configured developer build commands. The project must preserve historical attribution while avoiding unverified asset reuse and accidental public distribution.

## Decision drivers

- Private personal use is the current scope.
- Hardened Runtime has a tested local signing path.
- App Sandbox supports bookmarks and network entitlements, but external tool execution has material constraints.
- No historic visual asset has verified release provenance.

## Considered options

1. **Private hardened-runtime preview without App Sandbox.** Selected for v1 development and private testing.
2. **Mac App Store/App Sandbox immediately.** Deferred: requires a separate solution for arbitrary structured build commands and Store distribution work.
3. **Unsigned builds.** Rejected: signing/hardened-runtime behavior must be exercised early.
4. **Public distribution now.** Rejected: it changes licensing, Developer ID/notarization, support, asset, and threat-model obligations.

## Decision

Build a locally signed arm64 private preview with Hardened Runtime. Do not enable App Sandbox in v1 until a later feature verifies selected-folder bookmarks, loopback listener entitlements, and structured build-command execution under sandbox restrictions. Bind the reload server to loopback in code regardless. Persist only security-scoped bookmarks for selected folders. Exclude all historical visual assets and legacy frameworks from modern archives; retain original notices in `NOTICE.md`.

## Consequences

- Positive: a modern private preview can be built and exercised now without claiming distribution readiness.
- Negative: App Store/public distribution remains out of scope; sandboxing must be designed later rather than retrofitted casually.
- Follow-up: Phase 4 must evaluate Developer ID/notarization, physical clean-account launch, privacy strings, final entitlements, and any public-release request.

## Verification

- `Research/SigningPrototype/` and `docs/modernization/evidence/signing/signing-prototype.md` prove local arm64 Hardened Runtime signing.
- `docs/modernization/distribution-research.md` links primary Apple documentation and source facts.
- `docs/modernization/asset-provenance.md` excludes historical artwork from the modern release path.
