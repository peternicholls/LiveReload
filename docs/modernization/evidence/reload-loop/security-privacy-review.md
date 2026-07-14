# Phase 2 Security and Privacy Review

**Evidence ID:** EV-P2-009  
**Result:** PASS  
**Date:** 2026-07-14

## Scope

The review covered Phase 2 file monitoring and path normalization, ignore-rule
matching, protocol-7 and RFC 6455 parsing, the loopback listener and browser
sessions, pipeline delivery, folder-access lifetime, app diagnostics, browser
and idle harness separation, captured evidence, and dependency provenance.

The modern target has no external Swift package dependency. The Node browser
fixture uses host-provided built-in modules and is not linked or bundled into
the application. Vendored historical dependencies and test keys remain legacy
reference material excluded from the modern product.

## Findings and resolution

The initial review found no critical or high issue. It found two medium local
trust-boundary defects recorded as ISS-007:

1. An unrelated browser origin could complete a WebSocket upgrade against the
   loopback endpoint.
2. Connected or HTTP-upgraded clients could occupy all 32 session slots without
   completing the protocol-7 hello.

Both were fixed regression-first. The parser now accepts absent Origin for
native/raw clients and exact `http` or `https` loopback origins only. It rejects
external, opaque, credential-bearing, path/query/fragment-bearing, malformed,
control-containing, and duplicate Origin values. Every non-ready session owns a
two-second negotiation deadline on the same serial queue as its descriptor and
state; the deadline is cancelled and cleared on readiness, closure, and
deinitialization.

## Verification

- Parser and live-server origin tests prove absent, `127.0.0.1`, and
  `localhost` origins can negotiate, while hostile or malformed values receive
  HTTP 400 rather than 101.
- Saturation coverage opens 32 mixed raw-TCP and HTTP-upgraded sessions, proves
  they expire, then connects and negotiates a valid protocol-7 browser.
- Independent live probes observed incomplete sessions close after about 2.06
  seconds and a ready client remain open beyond 2.62 seconds.
- The full core suite passes 92 tests across seven suites with warnings treated
  as errors, and the Release package build passes with the same policy.
- The production Safari and Chromium fixture passes after hardening: both
  clients negotiate protocol 7, receive one stylesheet and one full-page
  reload, and never use the research WebSocket server.
- Secret, private-path, bookmark, peer-address, raw-message, build-product, and
  volatile-agent-metadata scans pass for Phase 2 fixtures and evidence.
- `swift package show-dependencies --format json` reports zero external package
  dependencies.

## Residual boundaries

- RFC-required SHA-1 is used only to derive the WebSocket handshake accept
  value; it is not used for authentication or data integrity.
- WebSocket transport remains plaintext because it is bound to IPv4 loopback.
- A malicious native process can reconnect or complete raw negotiation. Any
  capability token, authentication, non-loopback serving, or extension origin
  requires a separate threat model and compatibility contract.
- Historical test certificates and keys remain excluded legacy reference files
  and are not present in the modern target or captured Phase 2 evidence.

**Re-audit verdict:** both medium findings are resolved. No critical, high,
medium, or actionable low finding remains in the Phase 2 production boundary.
