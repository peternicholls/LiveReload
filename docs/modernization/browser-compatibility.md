# Browser Compatibility Matrix

**Task groups:** Phase 0 T019–T025; Phase 2 `003-reload-loop` T030/T038
**Fixture:** `Research/BrowserFixture/`
**Protocol:** `http://livereload.com/protocols/official-7`
**Connection method:** Direct, disposable protocol-7 fixture client over loopback; no extension or bundled third-party browser client.

## Observation procedure

1. Start `node Research/BrowserFixture/server.mjs`.
2. Open `http://127.0.0.1:35731/` in the target browser.
3. Confirm the fixture records a client `hello` offering protocol 7 and a client-side `hello` acknowledgement.
4. Request `/trigger?path=/styles.css&liveCSS=true`; confirm a client reload acknowledgement.
5. Request `/trigger?path=/index.html&liveCSS=false`; confirm a client reload acknowledgement, WebSocket close, reconnect, and a new protocol-7 hello.
6. Stop the fixture and retain only sanitized observations.

## Compatibility results

| ID | Browser | Version | Hello | CSS reload | Page reload / reconnect | Classification | Evidence |
|---|---:|---|---|---|---|---|
| OBS-001 | Safari | 26.5.2 | Sent protocol-7 hello; received server hello | Received `/styles.css` with `liveCSS=true`; initial and cache-busted stylesheets loaded with two rules and returned 200 | Received `/index.html`; sent close, reconnected, and sent a new hello | supported for direct protocol fixture | Initial fixture events 2026-07-11; corrected CSS-resource run 2026-07-13 via SafariDriver |
| OBS-002 | Google Chrome (headless) | 149.0.7827.201 | Sent protocol-7 hello; received server hello | Received `/styles.css` with `liveCSS=true`, updated stylesheet URL, and cache-busted stylesheet request returned 200 | Received `/index.html`; sent close, reconnected, and sent a new hello | supported for direct protocol fixture | Initial fixture events 2026-07-11; corrected CSS-resource run 2026-07-13 |

## Phase 2 production-server revalidation

On 2026-07-14 the reusable direct protocol fixture ran twice against the production `LiveReloadCore.ReloadServer` at `127.0.0.1:35729/livereload`. The fixture's separate research WebSocket endpoint retained zero clients, proving that the result did not accidentally exercise the Phase 0 server.

| ID | Browser | Production protocol-7 hello | Stylesheet decision | Full-page decision / reconnect | Result | Evidence |
|---|---|---|---|---|---|---|
| OBS-003 | Safari 26.5.2 | accepted; production server reported a ready client | exactly one `styles.css` reload with `liveCSS=true`; cache-busted stylesheet returned successfully | exactly one `index.html` reload followed by one new hello | supported for the recorded Phase 2 production build | `docs/modernization/evidence/reload-loop/browser-compatibility-2026-07-14.md` |
| OBS-004 | Google Chrome 149.0.7827.201 (headless) | accepted; production server reported a ready client | exactly one `styles.css` reload with `liveCSS=true`; cache-busted stylesheet returned successfully | exactly one `index.html` reload followed by one new hello | supported for the recorded Phase 2 production build | `docs/modernization/evidence/reload-loop/browser-compatibility-2026-07-14.md` |

Both broadcasts reported two sends and zero failures. The same fixture passed again after loopback-Origin enforcement and the two-second negotiation deadline were added. This closes the Phase 2 production compatibility obligation for current Safari and Chromium; it does not claim extension packaging, bundled `livereload-js`, remote-device access, or every historical browser version.

## Captured evidence summary

Both clients sent this hello shape:

```json
{
  "command": "hello",
  "protocols": ["http://livereload.com/protocols/official-7"],
  "id": "phase-0-browser-fixture",
  "name": "Phase 0 Browser Fixture",
  "version": "1.0"
}
```

Both clients acknowledged the stylesheet and page reload messages. Following the page reload, the fixture observed a close frame, reduced its connection count, and then observed a new WebSocket connection and hello from each browser.

## Maintained client reference

The maintained reference source selected for later compatibility testing is [`livereload/livereload-js`](https://github.com/livereload/livereload-js), observed at repository HEAD `04867e406477c56699c4ad72108b2e907532d93c`, package version 4.0.2, MIT licence, on 2026-07-11. Its source is not copied into this repository; v1 will test it separately as a client of the production server.

## Limits

- This establishes direct protocol behavior in current Safari and Chrome, including the Phase 2 production server, not extension packaging or third-party client-bundle behavior.
- The fixture is a Node.js research harness and is not a production server candidate.
- CSS hot-swap is observed through the fixture's stylesheet URL update; visual stylesheet semantics remain a Phase 4 compatibility test.
