# Changelog

All notable modern application changes are recorded here. Entries describe user-visible, compatibility, security, distribution, and developer-workflow impact; internal commits alone are not release notes.

## Unreleased

### Added

- Project-wide versioning, changelog, software-inclusion, and living-guide governance.
- Native arm64 macOS 15+ SwiftUI project lifecycle foundation with versioned configuration, recoverable folder access, atomic persistence, bounded redacted activity, and accessible empty/available/repair/removal states.
- Dependency-free `LiveReloadCore` package and repeatable modern verification command.
- Explicit per-project FSEvents monitoring with visible stopped, starting, watching, recovering, and failed states.
- Normalized project-relative ignore rules and deterministic 100–500 ms change settling with bounded, de-duplicated activity summaries.
- A loopback-only protocol-7 WebSocket server, compatible-client count, stylesheet/full-page reload classification, and manual browser reload.
- Recovery and isolation coverage for folder loss, dropped/root-change events, port conflicts, malformed or slow clients, disconnects, and server restart.

### Changed

- Restored folder bookmarks are now resolved and access-checked on launch; unavailable projects remain configured and surface a repair state.
- Configuration loading now validates nested persisted values, detects newer schemas before decoding their shape, and prevents writes when an unreadable source could not be preserved.
- Activity summaries now redact arbitrary absolute paths and file URLs, including persisted events decoded from storage.
- Activity summaries now also redact authorization headers, embedded URL credentials, and common access-key field names.
- Project controls now disable while that project is being changed, preventing overlapping same-project mutations without blocking independent project IDs.
- Unreadable, newer-version, and unavailable configuration stores now show a dedicated write-protected recovery state; failure to resolve Application Support no longer crashes at launch.
- Runtime monitor, listener, pipeline, and browser-session state remains memory-only and requires explicit user start after launch.
- Project mutations and runtime actions now share per-project operation gates so rapid input cannot overlap rename, repair, monitoring, or reload operations.
- No modern application build has been released yet; build execution, automatic monitoring restoration, App Sandbox, public distribution, extension bundling, URL override, and non-loopback serving remain deferred.

### Security

- Browser serving is restricted to `127.0.0.1:35729` and `/livereload`; HTTP headers, WebSocket frames/messages, protocol fields, client count, and diagnostics are bounded.
- User-visible monitoring/server failures and reload results use redacted activity summaries; bookmark data, peer addresses, arbitrary absolute paths, credentials, and raw untrusted messages are not displayed or persisted.

## 0.0.0 — Unreleased baseline

This repository contains the original LiveReload source as reference material plus modernization planning/research artifacts. It is not a modern distributable application release.
