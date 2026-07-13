# Modern LiveReload Developer Guide

## Current workflow

1. Start feature work from the active Spec Kit feature branch; the feature `tasks.md` is the execution ledger.
2. Follow the constitution and Phase 0 ADRs. Do not import legacy implementation or add dependencies without recorded justification.
3. Add tests/fixtures before behavior where practical. Run the applicable Debug, Release, unit, integration, UI, privacy, and signing checks before marking a task complete.
4. Update the issue, solution, learning, ADR, sprint-review, guide, changelog, and inclusion-register records affected by the change.
5. Use Lore-format commits. Before release/merge, run the documented verification command and review `VERSIONING.md`, `CHANGELOG.md`, `NOTICE.md`, and `docs/project-ledger/software-inclusions.md`.

## Documentation change checklist

- User-visible flow, error, permission, compatibility, or limitation changed: update `user-guide.md`.
- Build, test, architecture, dependency, signing, or release workflow changed: update this guide.
- New code, package, asset, generator, tool, service, or copied material: update the inclusion register and `NOTICE.md` if required.
- Releasable change: update `CHANGELOG.md` and select/version according to `VERSIONING.md`.

Phase 1 will replace this planning workflow with exact `scripts/verify-modern.sh` commands once that script exists.
