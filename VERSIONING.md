# Versioning Policy

Modern LiveReload uses Semantic Versioning (`MAJOR.MINOR.PATCH`) for every releasable modern application build.

## Pre-1.0 policy

- `0.MINOR.0` marks a planned, compatibility-relevant feature set or a change that would be breaking after 1.0.
- `0.MINOR.PATCH` contains backward-compatible corrections, documentation-only fixes, and internal changes that do not alter the agreed feature set.
- `0.0.0` is reserved for unreleased planning/reference work and is not a distributable application version.

## Version source of truth

When the modern Xcode project exists, its marketing/build version must be generated from a single version configuration file owned by the modern target. `CHANGELOG.md`, release tag, archive metadata, and the app About surface must agree with it.

## Release procedure

1. Select the next version according to this policy.
2. Move verified changes from `Unreleased` into a dated `CHANGELOG.md` release section.
3. Review `docs/project-ledger/software-inclusions.md` and `NOTICE.md` for inclusion/attribution impact.
4. Run the required verification, signing, architecture, privacy, guide, and clean-account checks.
5. Tag the exact verified commit as `vMAJOR.MINOR.PATCH`.

Do not retag a published version. Correct a release with a new version and changelog entry.
