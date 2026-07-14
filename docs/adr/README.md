# Architecture Decision Records

Use sequential files such as `001-websocket-server.md`. ADRs are immutable once accepted; replace a decision with a new ADR that marks the earlier record as superseded.

## Active decisions

| ADR | Status | Current consequence |
|---|---|---|
| [ADR-001 — Own the minimal LiveReload RFC 6455 server](001-websocket-server.md) | accepted, implemented in Phase 2 | Keep the production endpoint loopback-only, bounded, protocol-7 typed, and independently browser-verified. |
| [ADR-002 — Use direct FSEvents with security-scoped bookmark repair](002-monitoring-and-folder-access.md) | accepted, implemented in Phases 1–2 | Copy callback values before actor handoff; treat loss/root flags as visible recovery; balance scoped access. |
| [ADR-003 — Distribution security](003-distribution-security.md) | accepted | Private Hardened Runtime posture remains; public distribution and historical assets require a new review. |

## Template

```markdown
# ADR-NNN: Decision title

- Status: proposed | accepted | superseded | rejected
- Date: YYYY-MM-DD
- Deciders: names or roles
- Related tasks/issues: IDs
- Supersedes: ADR-NNN or none

## Context

What forces and constraints require a decision?

## Decision drivers

- Driver

## Considered options

1. Option
2. Option

## Decision

What is chosen and where does the boundary sit?

## Consequences

- Positive
- Negative/trade-off
- Follow-up obligation

## Verification

Prototype, tests, benchmarks, or primary documentation that validates the choice.
```
