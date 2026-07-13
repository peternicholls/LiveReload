# Project Ledger

This directory is the durable operational memory for the modernization. It complements the task checkboxes in `.omx/plans/modern-apple-silicon-rewrite.md`.

## Records

- `issues.md`: problems, defects, blockers, risks, and unanswered technical questions.
- `solutions.md`: verified fixes and diagnostic recipes worth reusing.
- `learnings.md`: discoveries, constraints, and insights that should influence later work.
- `../adr/`: durable architectural decisions and superseding decisions.
- `../modernization/sprint-reviews/`: sprint goals, verification evidence, and retrospectives.

## Workflow

1. Start work from a task ID in the plan.
2. Record an unexpected problem as `ISS-NNN` before or during investigation.
3. Link commits, tests, logs, or reproduction fixtures rather than pasting large output.
4. If the resolution is reusable, add `SOL-NNN` and link it to the issue.
5. If the work changes an architectural choice, add or supersede an ADR.
6. Capture non-obvious findings as `LRN-NNN` while they are fresh.
7. Update the sprint review and only then check the plan task when its evidence is complete.

## Status Vocabulary

- Issues: `open`, `investigating`, `blocked`, `resolved`, `accepted-risk`, `wont-fix`.
- Severity: `critical`, `high`, `medium`, `low`.
- Solutions: `proposed`, `verified`, `superseded`.
- Learnings: `candidate`, `validated`, `superseded`.

IDs are never reused. Resolved and superseded records remain in place so history is searchable.
