# Phase 0 Quickstart

## 1. Confirm context

```bash
git branch --show-current
git status --short
```

Expected feature branch: `001-discovery-baseline`. Preserve unrelated user changes.

## 2. Read governing artifacts

1. `.specify/memory/constitution.md`
2. `specs/001-discovery-baseline/spec.md`
3. `specs/001-discovery-baseline/plan.md`
4. `specs/001-discovery-baseline/tasks.md`
5. `docs/project-ledger/README.md`

## 3. Execute in dependency order

1. Behavior inventory and sanitized protocol fixtures.
2. Standalone browser fixture and compatibility observations.
3. WebSocket prototype and ADR-001.
4. FSEvents/bookmark prototype and ADR-002.
5. Licence/assets/signing research, `NOTICE.md`, and ADR-003.
6. Ledger traceability exercise and sprint review.

Do not begin production application targets in this feature.

## 4. Record unexpected work

- Add problems/blockers to `docs/project-ledger/issues.md`.
- Add verified reusable fixes to `solutions.md`.
- Add non-obvious findings to `learnings.md`.
- Add architectural decisions under `docs/adr/`.
- Link every record to its Spec Kit task ID.

## 5. Verify phase exit

Run prerequisite and cross-artifact checks, then complete `docs/modernization/sprint-reviews/sprint-0.md`. Phase 0 is ready only when all tasks and requirements pass, ADR-001/002/003 are accepted, compatibility/prototypes are reproducible, the constitution check passes, and no architecture-blocking issue is open.

