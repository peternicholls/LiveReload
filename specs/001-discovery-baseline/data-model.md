# Phase 0 Artifact Data Model

These are documentation/data contracts, not production persistence types.

## Behavior Record

- `id`: stable `BEH-NNN`
- `name`: concise observable behavior
- `actor`: user, browser client, filesystem, or application
- `preconditions`, `action`, `outcome`
- `evidence[]`: repository reference, test, runtime observation, or primary source
- `classification`: `v1 | deferred | rejected`
- `futureVerification`: named unit/integration/UI/end-to-end/manual check
- `notes`: limitations or conflicting evidence

Rules: evidence and classification are mandatory; a `v1` record requires future verification.

## Protocol Fixture

- `id`: stable `FXT-NNN`
- `direction`: `client-to-server | server-to-client`
- `scenario`: hello, reload, invalid JSON, unsupported protocol, unknown command
- `payload`: sanitized JSON/text
- `expectedResult`: typed interpretation or rejection
- `sourceEvidence`

Rules: no credentials, personal paths, or copyrighted browser bundles; malformed cases are retained deliberately.

## Compatibility Observation

- `id`: stable `OBS-NNN`
- `browser`, `browserVersion`, `client`, `clientVersion`
- `connectionMethod`: script tag, extension, or direct fixture
- `scenario`, `procedure`, `observedResult`
- `classification`: `supported | partial | unsupported | blocked`
- `evidence`, `observedAt`

Rules: inference is labelled; an observation applies only to the recorded versions/scenario.

## Research Finding

- `id`: stable `RES-NNN`
- `question`, `method`, `directObservation`
- `interpretation`, `limitations`, `consequence`
- `evidence[]`
- `status`: `candidate | validated | superseded`

## Architecture Decision

- `id`: `ADR-NNN`
- `status`: `proposed | accepted | rejected | superseded`
- `context`, `drivers[]`, `options[]`, `decision`
- `positiveConsequences[]`, `negativeConsequences[]`, `followUps[]`
- `verification[]`, `supersedes`, `date`

Rules: accepted ADRs have executable or primary-source verification and no unresolved placeholders.

## Ledger Relationship

```text
Plan task ─► ISS-NNN ─► SOL-NNN
    │           ├────► LRN-NNN
    │           └────► ADR-NNN
    └────────────────► Sprint review evidence
```

Issue, solution, and learning field contracts are defined in `docs/project-ledger/`; IDs are never reused.

## Asset Provenance Record

- `id`: stable `AST-NNN`
- `pathOrDescription`, `source`, `creator`
- `termsOrEvidence`, `classification`: `reusable | replace | excluded | unknown`
- `modernReleaseTreatment`, `openQuestions[]`

Rules: `unknown` assets are excluded from the release path.

## Phase Readiness Verdict

- `phase`: `0`
- `date`, `constitutionVersion`
- `requirementsResult`, `taskResult`, `adrResult`, `prototypeResult`, `compatibilityResult`
- `openBlockingIssues[]`
- `verdict`: `ready | not-ready`
- `evidence[]`

Rule: `ready` requires an empty `openBlockingIssues` list.

