# Browser Fixture

Purpose: independently observe LiveReload browser-client negotiation and reload behavior before choosing the production server architecture.

This is a disposable, loopback-only Node.js 26.5.0 research harness using only `node:http` and `node:crypto`.

- `server.mjs` serves `/`, `/styles.css`, `/status`, and `/trigger` on `127.0.0.1:35731` by default.
- `/livereload` accepts a minimal WebSocket connection, records the client `hello`, sends the protocol-7 server `hello`, and broadcasts `reload` messages injected through `/trigger`.
- `index.html` is a direct protocol-7 client. It hot-swaps its stylesheet on a CSS reload and performs `location.reload()` for a non-CSS reload.
- Start with `node server.mjs`, then browse to `http://127.0.0.1:35731/`. Stop with `Ctrl-C`.

The maintained compatibility reference is [`livereload/livereload-js`](https://github.com/livereload/livereload-js), repository HEAD `04867e406477c56699c4ad72108b2e907532d93c`, package version 4.0.2, MIT licence, observed 2026-07-11. Its client bundle is deliberately not copied into this repository: this fixture tests the published protocol directly and is not a production server.
