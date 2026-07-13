# Research Artifact Contract

Every research output must satisfy this contract before its task is checked complete.

## Required properties

1. Stable ID or stable repository path.
2. Related Spec Kit requirement and task IDs.
3. Exact question or behavior examined.
4. Method sufficiently precise to repeat.
5. Direct observation separated from interpretation.
6. Evidence link: fixture, command/result artifact, repository reference, primary documentation, screenshot, or benchmark.
7. Tool, SDK, OS, browser, or app version where results are version-sensitive.
8. Limitations and unsupported claims.
9. Consequence: decision, follow-up task, issue, or explicit no-change result.
10. Sanitization: no credentials, tokens, private contents, or unnecessary personal paths.

## Completion states

- `candidate`: captured but not independently repeated or corroborated.
- `validated`: repeated/corroborated and suitable for a decision.
- `superseded`: retained for history and linked to replacement evidence.

Only validated evidence may close an architecture-blocking question.
