# Browser Fixture Run

- **Tasks:** T022, T023, T025
- **Date:** 2026-07-11
- **Host:** Apple silicon macOS 26.5.2
- **Fixture command:** `node Research/BrowserFixture/server.mjs`

## Historical results

- Safari 26.5.2 connected, sent protocol-7 hello, received CSS and page reload commands, acknowledged each reload, closed after page reload, and reconnected with hello. This observation predates the correction that placed `styles.css` in the fixture directory, so stylesheet-resource loading must be repeated before treating the CSS result as current.
- Google Chrome 149.0.7827.201 (headless) produced the same sequence. The corrected fixture was revalidated with HeadlessChrome 149 on 2026-07-13; its initial and cache-busted stylesheet requests returned 200.
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

Safari stylesheet-resource revalidation requires either enabling Safari Settings → Developer → Allow remote automation or a manual fixture run. It is not enabled on this host, so this record does not overstate the corrected CSS result.
