# Phase 2 Reload Loop Evidence Index

This directory is the completed feature evidence index for `003-reload-loop`.
Evidence is generated from disposable projects and sanitized before it is
linked here. Every Phase 2 evidence gate is closed.

| Evidence ID | Gate | Owning tasks | Artifact or source | State |
|---|---|---|---|---|
| EV-P2-001 | Sanitized fixtures | T001 | `tests/fixtures/reload-loop/` | Available |
| EV-P2-002 | Verification contract | T002 | `verification-matrix.md` | Available |
| EV-P2-003 | Pre-implementation consistency | T005 | `cross-artifact-analysis.md` | Pass |
| EV-P2-004 | Core runtime contracts | T003, T006–T009 | 92-test Debug run and Release build in `sprint-2.md` | Pass |
| EV-P2-005 | Monitoring lifecycle | T010–T016 | Workspace integration, app, UI, and `idle-resources.md` | Pass |
| EV-P2-006 | Filtering and batching | T017–T021 | Exclusion, settlement, and 10,000-event regressions in `sprint-2.md` | Pass |
| EV-P2-007 | Protocol and raw server | T022–T029 | Protocol, frame, server, pipeline, app, and UI results in `sprint-2.md` | Pass |
| EV-P2-008 | Safari and Chromium | T030 | `browser-compatibility-2026-07-14.md` | Pass |
| EV-P2-009 | Recovery and isolation | T031–T033 | Integration/UI results and `security-privacy-review.md` | Pass |
| EV-P2-010 | Idle resources | T034 | `idle-resources.md` | Pass |
| EV-P2-011 | Full release verification | T035–T037 | `scripts/verify-modern.sh` and `sprint-2.md` | Pass |
| EV-P2-012 | Closure consistency | T038–T039 | `final-cross-artifact-analysis.md` and synchronized ledgers/roadmap | Pass |

## Evidence hygiene

- Record commands, configuration, result, and date.
- Use repository-relative fixture paths and invented project identifiers.
- Do not retain absolute user paths, credentials, bookmark bytes, environment
  values, browser profile data, raw peer addresses, or private source content.
- Keep failed gates visible as failed until a later linked artifact proves the
  rerun passed.
- Treat the accepted Phase 0 browser/protocol evidence as input; Phase 2 must
  rerun compatibility against the production server before claiming support.
