# Local Reload Protocol Contract

## Exposure

- Bind only to `127.0.0.1` on the documented LiveReload port using the owned Darwin BSD-socket listener; do not substitute the rejected `Network.framework` server path.
- Accept only the `/livereload` endpoint.
- Reject requests that cannot complete a valid WebSocket upgrade or exceed bounded header, frame, message, or client limits.

## Connection lifecycle

1. Perform the WebSocket upgrade.
2. Require a masked client `hello` message that advertises a supported LiveReload protocol version.
3. Negotiate protocol 7 before registering the client as ready.
4. Accept bounded text, ping, pong, and close frames; reject unsupported, malformed, or oversized input by closing only that session.
5. Remove closed sessions from the client count immediately.

## Reload messages

- A stylesheet-only batch sends a protocol-7 reload message with live stylesheet behavior enabled.
- Other meaningful batches and manual reload send a safe full-page reload message.
- Excluded-only batches, stopped monitoring, recovery, and no-ready-client cases send no message.

## Failure behavior

- Port conflict transitions the server to a retryable conflict state; it does not stop monitoring or alter project configuration.
- One client failure does not affect other ready clients.
- Diagnostics use safe message categories and never retain raw headers, frames, peer addresses, secrets, or full project paths.

## Verification

Raw-frame tests cover upgrades, endpoint rejection, negotiation, masking, bounds, ping/pong, close, invalid input, multiple clients, disconnect cleanup, restart, and port conflict. Safari and Chromium fixtures validate the accepted browser behavior before a compatibility claim.
