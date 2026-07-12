# WebSocket Prototype Scenarios

These expectations are defined before prototype implementation (T026). They are exercised by `scripts/exercise.sh` after the server exists.

| Scenario | Expected result |
|---|---|
| Bind | Listener reports ready on `127.0.0.1:35732`. |
| Valid hello | Browser WebSocket client receives server `hello` after sending a protocol-7 hello. |
| Reload | `POST /reload` is not part of this prototype; sending `reload` through stdin broadcasts to every connected client. |
| Multiple clients | Two clients receive the same reload payload. |
| Disconnect | Client close removes the client from the server and later broadcasts do not fail. |
| Malformed input | Invalid JSON receives no server hello/reload and is logged as invalid without crashing the listener. |
| Port collision | A second instance on the same port reports listener failure and exits nonzero. |

The prototype deliberately tests WebSocket capability only. HTTP hosting, `/livereload` routing, and static assets remain a separate production design decision.
