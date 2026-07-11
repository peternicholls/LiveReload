# LiveReload Modernization Constitution

**Version:** 1.0.0  
**Ratified:** 2026-07-11  
**Last amended:** 2026-07-11

## Purpose

This constitution governs the Apple-silicon modernization of LiveReload. It exists to protect the useful behavior of the original application while ensuring that the replacement is maintainable, secure, verifiable, and honest about what it supports. These rules apply to planning, research, implementation, review, testing, packaging, and documentation.

## Article I — Behavior Before Implementation

1. User-visible behavior and published interoperability protocols are the source of truth; legacy internal architecture is evidence, not a design mandate.
2. Every behavior retained in v1 must appear in the behavior inventory and have an automated or explicitly documented manual verification.
3. The rewrite must not mechanically translate obsolete Swift, Objective-C, CoffeeScript, or bundled-runtime implementation where a current platform API provides a clearer boundary.
4. A change that intentionally alters observed behavior requires a recorded decision and updated acceptance criteria before implementation.

**Rationale:** preserving outcomes while replacing obsolete mechanisms is the core purpose of the rewrite.

## Article II — Native, Modern, and Minimal

1. Production code targets Apple silicon, Swift 6.2 strict concurrency, and macOS 15 or later unless a recorded ADR changes the baseline.
2. SwiftUI is the default presentation framework; AppKit and C APIs are isolated behind narrow adapters where platform capability requires them.
3. The app must not require Rosetta or embed Node.js, Ruby, CoffeeScript, historical compiler toolchains, telemetry, advertising, licensing, or updater services.
4. New dependencies require an ADR showing why Apple frameworks or a small local implementation are inadequate, plus licence, maintenance, security, binary-size, and removal analysis.
5. Prefer deletion, standard-library/platform capabilities, and explicit data flow over compatibility layers and speculative abstraction.

**Rationale:** the old dependency graph is the principal source of obsolescence and must not be recreated in modern form.

## Article III — Safe Concurrency and Explicit Ownership

1. Mutable service state belongs to an actor or `@MainActor`; values crossing isolation boundaries must be Sendable.
2. FSEvents and other callback-based APIs must copy callback data immediately and cross into Swift concurrency through typed values.
3. Service lifecycle must be explicit and idempotent: start, stop, cancellation, teardown, and error recovery are tested states.
4. No project may have overlapping builds. A child process, listener, event stream, bookmark access, or client session must have one identifiable owner.
5. Blocking I/O, unbounded tasks, detached tasks without ownership, and ignored cancellation are prohibited.

**Rationale:** a menu-bar utility runs for long periods; lifecycle leaks and concurrency ambiguity are product defects.

## Article IV — Security and Privacy by Default

1. The reload server binds to loopback by default. Any broader network exposure requires a separate threat model, explicit user action, authentication decision, and ADR.
2. Build commands use an executable plus argument array. Production code must not interpolate configuration into a shell command.
3. Network messages, paths, persisted files, bookmarks, environment additions, and process output are untrusted inputs and must be validated and bounded.
4. Logs and diagnostics must redact secrets and avoid persisting full environments or unrelated user file contents.
5. Folder access is least-privilege and recoverable. Stale permissions must be repaired explicitly, never bypassed or silently discarded.
6. Security findings block release until fixed or accepted in writing with scope, impact, mitigation, and review date.
7. Archived or untrusted binaries may be executed for research only after static inspection and hash/signature capture, inside a disposable account or isolated environment with no private project mounts, no credentials, and restricted networking; execution is optional and may be replaced by source/test evidence.

**Rationale:** local developer tools handle source trees, processes, and network input and therefore have meaningful trust boundaries.

## Article V — Evidence-Driven Delivery

1. Every task is tracked by a stable ID and Markdown checkbox in the approved plan. A checked task means its acceptance evidence exists, not merely that code was written.
2. Behavior changes follow regression-first development: capture a failing test or fixture before the fix when technically possible.
3. Each story must satisfy its acceptance criteria and sprint exit gate; incomplete stories remain incomplete and are re-planned visibly.
4. Debug and Release builds must treat warnings as errors. Required unit, integration, UI, end-to-end, performance, and release checks must pass before their associated gate closes.
5. Claims of compatibility, performance, security, or completion must cite commands, fixtures, measurements, or captured observations.
6. A failing verification step is work to continue, not a reporting footnote.

**Rationale:** the project is successful only when behavior is demonstrably reliable on a current Apple-silicon Mac.

## Article VI — Accessible and Actionable Experience

1. Every user-visible state must be understandable without color alone and operable by keyboard.
2. Controls require accessibility labels and logical VoiceOver order; major flows receive UI-test identifiers.
3. Empty, loading, paused, permission-loss, missing-folder, port-conflict, build-failure, and recovery states are first-class product states.
4. Errors explain what happened, what was preserved, and the next safe action. Silent failure is prohibited.
5. Light/dark appearance, reduced motion, text scaling, path overflow, and long process output must not break core workflows.

**Rationale:** a dependable utility communicates its state clearly, especially when background work fails.

## Article VII — Durable Project Memory

1. The active Spec Kit feature's `tasks.md` is the authoritative executable task ledger; the parent modernization roadmap tracks phase-level status and must be synchronized at phase gates. GitHub issues may mirror either level but must retain stable task/story IDs.
2. Problems discovered during work are recorded in `docs/project-ledger/issues.md` before or alongside investigation.
3. Reusable fixes and diagnostic recipes are recorded in `docs/project-ledger/solutions.md` and linked to their issue, task, test, commit, and ADR where applicable.
4. Unexpected findings, constraints, and reusable insights are recorded in `docs/project-ledger/learnings.md` during the sprint in which they arise.
5. Architectural decisions use numbered ADRs in `docs/adr/`. Reversing an ADR requires a superseding ADR; history is not erased.
6. Sprint reviews record verification evidence, unfinished work, new risks, issues, solutions, and learnings.
7. Absolute local paths, credentials, access tokens, private source contents, and personal data must never enter the ledger.

**Rationale:** the rewrite spans multiple phases; decisions and discoveries must survive context loss and prevent repeated investigation.

## Article VIII — Scope, Attribution, and Release Integrity

1. V1 scope and deferrals in the approved plan are binding. A new feature enters active work only through a plan amendment with acceptance criteria and impact on schedule/tests.
2. Historical copyright, licence, author, and purchasing-policy notices are retained as required. New work is clearly identified.
3. Assets ship only with known provenance and permission; unknown historical artwork is replaced.
4. Public binary distribution is a separate decision and is not implied by a successful private preview.
5. A release must be reproducible from a tagged commit and include architecture, signing, entitlement, dependency, test, and clean-account smoke evidence.
6. Legacy code remains reference material and is excluded from the modern release archive.

**Rationale:** scope control and provenance protect both the technical result and the people who created the original work.

## Quality Gates

No phase may close unless:

- all committed tasks are checked with linked evidence;
- story acceptance criteria and the sprint exit gate pass;
- new issues have severity and disposition;
- relevant ADRs, solutions, and learnings are updated;
- Debug and Release verification is green for affected targets;
- no known critical or high-severity security defect remains open;
- documentation reflects actual behavior and limitations.

## Governance

1. This constitution supersedes conflicting project conventions, plan text, and implementation convenience. Repository-level safety instructions still take precedence.
2. Amendments are proposed as a focused change that states motivation, affected articles, migration impact, and rejected alternatives.
3. Versioning follows semantic rules:
   - **MAJOR:** removes or fundamentally weakens a principle, quality gate, or governance guarantee.
   - **MINOR:** adds a principle or materially expands an obligation.
   - **PATCH:** clarifies wording without changing obligations.
4. An amendment updates this file, its version and date, and any affected plan, template, ADR, or verification checklist in the same change.
5. Every sprint review includes a constitution check. Violations are recorded as issues and must be corrected or resolved through an explicit amendment.
6. Exceptions must be temporary, written in the issue ledger with owner, reason, risk, compensating control, and expiry/review date. Permanent exceptions require an amendment.
