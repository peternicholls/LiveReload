# Implementation Plan: Discovery Baseline

**Branch**: `001-discovery-baseline` | **Date**: 2026-07-11 | **Status**: Review changes requested (ISS-004) | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-discovery-baseline/spec.md`

## Summary

Phase 0 establishes the verified behavioral and architectural baseline for the Apple-silicon LiveReload rewrite. It inventories legacy outcomes, validates current Safari/Chromium protocol behavior, builds isolated Swift WebSocket and FSEvents/bookmark prototypes, and records distribution/governance decisions. Production app implementation is explicitly excluded. The result is a set of fixtures, compatibility evidence, ADRs, ledgers, and a Phase 1 readiness verdict.

## Technical Context

**Language/Version**: Swift 6.2 for executable research harnesses; Markdown and JSON for durable artifacts
**Primary Dependencies**: Apple Foundation, Network.framework, CoreServices/FSEvents, AppKit for folder-selection/bookmark harness; no third-party production dependency
**Storage**: Version-controlled Markdown, sanitized JSON fixtures, small local fixture files; no database
**Testing**: Swift Testing or XCTest for harness tests, shell-driven fixture checks, Safari/Chromium manual-observation protocol with captured evidence
**Target Platform**: Apple-silicon Mac; research host macOS 26.5.2/Xcode 26.3; proposed production floor macOS 15+ remains subject to prototype evidence
**Project Type**: Research harnesses and architecture documentation for a desktop application rewrite
**Performance Goals**: Capture WebSocket event-to-message latency; verify FSEvents behavior under a 10,000-event synthetic burst; no production performance commitment in this phase
**Constraints**: Private/personal scope; no obsolete runtime execution unless isolated and safe; loopback-only networking; sanitized artifacts; prototypes cannot become production dependencies by accident
**Scale/Scope**: Five research stories, three ADRs, four executable research harnesses (browser fixture, WebSocket, FSEvents/bookmarks, and signing), one browser compatibility matrix, one behavior inventory, and governance/ledger validation

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / gate | Plan evidence | Result |
|---|---|---|
| Behavior before implementation | Inventory and protocol fixtures precede production design; legacy mechanisms are not ported | PASS |
| Native, modern, minimal | Swift 6.2 Apple-framework prototypes; no production third-party dependency | PASS |
| Safe concurrency and ownership | FSEvents callback copying and typed Sendable handoff are explicit prototype criteria | PASS |
| Security and privacy | Loopback binding, malformed-input checks, bounded evidence, and artifact sanitization are required | PASS |
| Evidence-driven delivery | Every finding ends in fixtures, observations, ADRs, or repeatable verification | PASS |
| Accessible/actionable experience | No production UI is delivered; bookmark repair research covers actionable failure state | PASS/N/A |
| Durable project memory | Spec Kit artifacts, ledgers, ADRs, stable IDs, and sprint review are required outputs | PASS |
| Scope/attribution/release integrity | Production work excluded; licence/asset/signing/sandbox posture is a dedicated story | PASS |

**Pre-research verdict:** PASS. No constitutional exception is requested.

## Phase 0: Research Method

Research decisions and methods are captured in [research.md](./research.md). Work proceeds in risk order:

1. Inventory legacy behavior and produce sanitized protocol fixtures.
2. Validate current browser negotiation independently of the macOS app.
3. Prototype the WebSocket server against those fixtures and record ADR-001.
4. Prototype FSEvents and bookmark lifecycle and record ADR-002.
5. Resolve private distribution, attribution, and asset handling in ADR-003 and `NOTICE.md`, including the isolated signing harness.
6. Exercise the project ledger and issue a Phase 1 readiness verdict.

Research may open issues, but Phase 1 cannot begin with an open architecture-blocking issue.

## Phase 1: Artifact Design

### Artifact model

[data-model.md](./data-model.md) defines the records created by this phase: behavior records, fixtures, compatibility observations, findings, ADRs, ledger records, and asset provenance entries.

### Contracts

There is no network product API in this phase. Contracts instead define artifact completeness and prototype boundaries:

- [contracts/research-artifacts.md](./contracts/research-artifacts.md)
- [contracts/prototype-boundaries.md](./contracts/prototype-boundaries.md)

### Operator workflow

[quickstart.md](./quickstart.md) defines the order for executing research, recording evidence, validating the constitution, and closing Phase 0.

## Post-Design Constitution Check

| Principle / gate | Design evidence | Result |
|---|---|---|
| Behavior before implementation | Behavior Record includes evidence, classification, and future verification | PASS |
| Native, modern, minimal | Prototype contract prevents importing research harness code/dependencies into production | PASS |
| Safe concurrency and ownership | Prototype result requires lifecycle and callback-handoff observations | PASS |
| Security and privacy | Artifact contract forbids secrets/personal paths and requires sanitized fixtures | PASS |
| Evidence-driven delivery | All entity types include evidence and verification fields | PASS |
| Accessible/actionable experience | Bookmark failure/repair is an explicit compatibility observation | PASS |
| Durable project memory | Ledger relationship model links task → issue → solution/learning/ADR → sprint review | PASS |
| Scope/attribution/release integrity | Asset provenance and distribution decision are first-class records | PASS |

**Post-design verdict:** PASS. No complexity exception or constitutional amendment is required.

## Project Structure

### Documentation (this feature)

```text
specs/001-discovery-baseline/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── prototype-boundaries.md
│   └── research-artifacts.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Research and durable project artifacts

```text
Research/
├── BrowserFixture/
├── WebSocketPrototype/
├── FSEventsPrototype/
└── SigningPrototype/

docs/
├── adr/
├── modernization/
│   ├── behavior-inventory.md
│   ├── browser-compatibility.md
│   └── sprint-reviews/
└── project-ledger/
    ├── issues.md
    ├── solutions.md
    └── learnings.md

tests/fixtures/livereload-protocol/
NOTICE.md
```

**Structure Decision**: Research code is isolated under `Research/`; durable findings live under `docs/`; machine-readable protocol evidence lives under `tests/fixtures/`; Spec Kit controls the phase under `specs/001-discovery-baseline/`. No file in `Research/` is part of the future production target by default.

## Complexity Tracking

No constitutional violations require justification.

## Phase Exit and Handoff

Phase 0 is ready to close only when:

1. The requirements checklist remains green.
2. Every Phase 0 task in `tasks.md` is complete with evidence.
3. ADR-001, ADR-002, and ADR-003 are accepted with no placeholders.
4. The compatibility matrix and both prototypes have repeatable results.
5. The sprint review reports no open architecture-blocking issue.
6. A cross-artifact Spec Kit analysis finds no critical inconsistency.
7. Phase 1 receives its own new Spec Kit feature branch and begins again at `specify`.
