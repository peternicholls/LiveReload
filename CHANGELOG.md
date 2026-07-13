# Changelog

All notable modern application changes are recorded here. Entries describe user-visible, compatibility, security, distribution, and developer-workflow impact; internal commits alone are not release notes.

## Unreleased

### Added

- Project-wide versioning, changelog, software-inclusion, and living-guide governance.
- Native arm64 macOS 15+ SwiftUI project lifecycle foundation with versioned configuration, recoverable folder access, atomic persistence, bounded redacted activity, and accessible empty/available/repair/removal states.
- Dependency-free `LiveReloadCore` package and repeatable modern verification command.

### Changed

- Restored folder bookmarks are now resolved and access-checked on launch; unavailable projects remain configured and surface a repair state.
- Configuration loading now validates nested persisted values, detects newer schemas before decoding their shape, and prevents writes when an unreadable source could not be preserved.
- Activity summaries now redact arbitrary absolute paths and file URLs, including persisted events decoded from storage.
- Project controls now disable while that project is being changed, preventing overlapping same-project mutations without blocking independent project IDs.
- No modern application build has been released yet; monitoring, browser reload, build execution, App Sandbox, and public distribution remain deferred.

## 0.0.0 — Unreleased baseline

This repository contains the original LiveReload source as reference material plus modernization planning/research artifacts. It is not a modern distributable application release.
