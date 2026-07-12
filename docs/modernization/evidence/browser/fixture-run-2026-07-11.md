# Browser Fixture Run

- **Tasks:** T022, T023, T025
- **Date:** 2026-07-11
- **Host:** Apple silicon macOS 26.5.2
- **Fixture command:** `node Research/BrowserFixture/server.mjs`

## Results

- Safari 26.5.2 connected, sent protocol-7 hello, received CSS and page reload commands, acknowledged each reload, closed after page reload, and reconnected with hello.
- Google Chrome 149.0.7827.201 (headless) produced the same sequence.
- The fixture's close-frame handling was corrected and re-run; connection count returned from two to one while a page reloaded, then returned to two after the second browser reconnected.

## Representative sanitized events

```text
connected (Safari) → received hello → client-event hello
connected (Chrome) → received hello → client-event hello
broadcast reload /index.html → client-event reload from both browsers
disconnected → connected → received hello (Chrome)
disconnected → connected → received hello (Safari)
```

## Limits

No browser extension or maintained `livereload-js` bundle was installed. The direct protocol fixture is sufficient for this Phase 0 compatibility observation; bundle/extension coverage remains Phase 4 work.
