# Reload Loop Fixtures

These fixtures are synthetic Phase 2 inputs for protocol-7 messages, RFC 6455
frames, browser compatibility scenarios, monitoring signals, exclusion rules,
and recovery behavior. They contain only project-relative paths and invented
identifiers.

The fixture set deliberately references, rather than copies, the Phase 0
research assets:

- `tests/fixtures/livereload-protocol/` is the accepted protocol evidence.
- `Research/BrowserFixture/` is the disposable Safari and Chromium harness.
- `Research/WebSocketPrototype/` is historical prototype evidence, not runtime
  code for the modern application.

Production tests may translate these documents into typed values, but must not
add credentials, bookmark bytes, peer addresses, absolute user paths, private
source contents, browser bundles, or legacy runtime code to this directory.

