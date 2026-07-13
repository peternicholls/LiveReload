# Phase 2 Reload Loop Evidence Index

This directory is the feature evidence index for `003-reload-loop`. Evidence
must be generated from disposable projects and sanitized before it is linked
here. A listed future artifact is a required destination, not a claim that its
gate already passes.

| Evidence ID | Gate | Owning tasks | Artifact or source | State |
|---|---|---|---|---|
| EV-P2-001 | Sanitized fixtures | T001 | `tests/fixtures/reload-loop/` | Available |
| EV-P2-002 | Verification contract | T002 | `verification-matrix.md` | Available |
| EV-P2-003 | Pre-implementation consistency | T005 | `cross-artifact-analysis.md` | Pass |
| EV-P2-004 | Core runtime contracts | T003, T006–T009 | Core test and build output | Planned |
| EV-P2-005 | Monitoring lifecycle | T010–T016 | Core integration, app, and UI results | Planned |
| EV-P2-006 | Filtering and batching | T017–T021 | Core burst and exclusion results | Planned |
| EV-P2-007 | Protocol and raw server | T022–T029 | Protocol, frame, server, pipeline, app, and UI results | Planned |
| EV-P2-008 | Safari and Chromium | T030 | Sanitized browser fixture run | Planned |
| EV-P2-009 | Recovery and isolation | T031–T033 | Integration and UI recovery results | Planned |
| EV-P2-010 | Idle resources | T034 | Five-minute CPU and lifecycle sample | Planned |
| EV-P2-011 | Full release verification | T035–T037 | Verification script output and Sprint 2 review | Planned |
| EV-P2-012 | Closure consistency | T038–T039 | Ledger/roadmap reconciliation and final analysis | Planned |

## Evidence hygiene

- Record commands, configuration, result, and date.
- Use repository-relative fixture paths and invented project identifiers.
- Do not retain absolute user paths, credentials, bookmark bytes, environment
  values, browser profile data, raw peer addresses, or private source content.
- Keep failed gates visible as failed until a later linked artifact proves the
  rerun passed.
- Treat the accepted Phase 0 browser/protocol evidence as input; Phase 2 must
  rerun compatibility against the production server before claiming support.

