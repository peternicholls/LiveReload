# Research Prototype Boundary Contract

## Allowed

- Small executable Swift harnesses under `Research/`.
- Apple platform frameworks and standard libraries.
- Fixture-only HTML/CSS/JavaScript required to test browser behavior.
- Deliberately simple diagnostics and local test configuration.

## Required

- README with purpose, build/run instructions, scenarios, and deletion/promotion criteria.
- Loopback-only listeners unless a test explicitly and safely proves otherwise.
- Bounded input and output during malformed/stress scenarios.
- Automated checks for deterministic behavior where feasible.
- No credentials, signing secrets, or personal absolute paths.

## Prohibited

- Importing a research target/module into the future production app by default.
- Treating prototype success as production completion.
- Adding a third-party dependency without the constitution's ADR analysis.
- Shipping historical binaries, browser bundles, artwork, or compiler runtimes inside a prototype.
- Publishing a binary from this phase.

## Promotion rule

A later Spec Kit phase may promote an algorithm or type only after restating its production requirements, adding lifecycle/security tests, and explicitly listing the promoted files in that phase's plan and tasks. Copying the entire harness is not presumed acceptable.

