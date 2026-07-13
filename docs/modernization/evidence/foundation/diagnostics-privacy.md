# Diagnostics Privacy Evidence

`ActivityStoreTests` appends 201 events and verifies that only the newest 200 remain. It also verifies the fixed category/severity sets, absolute-path redaction, secret-like value redaction, and 512-character summary bound before storage.

Command: `swift test --package-path Packages/LiveReloadCore`

Fixture inputs live under `tests/fixtures/modern-foundation/activity/` and contain synthetic values only. No private source contents, bookmark bytes, credentials, or environment values are included.
