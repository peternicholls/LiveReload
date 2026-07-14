# Modern LiveReload User Guide

## Status

The modern application is an unreleased private build. Phase 2 adds an explicit, local-only reload loop: a user starts monitoring for an enabled project, meaningful changes are settled into one batch, and compatible browsers connected to the loopback endpoint receive a stylesheet or full-page reload request. Build commands, automatic monitoring restoration, App Sandbox, public distribution, browser-extension bundling, URL override, and access from other devices remain unavailable.

## Supported behavior

| Capability | Status | Evidence / next owner |
|---|---|---|
| Add, restore, rename, enable, repair, and remove projects | implemented | `scripts/verify-modern.sh` and foundation evidence |
| Explicit project monitoring and recovery | implemented in Phase 2 private build | reload-loop core, integration, app, and UI tests |
| Local protocol-7 browser reload and manual reload | implemented in Phase 2 private build | raw-server tests and production browser compatibility evidence |
| Ignore rules and settled change batches | implemented in Phase 2 private build | ignore-rule and deterministic batching tests |
| Build commands | deferred | Phase 3 `developer-workflow` |
| Public distribution | deferred | Phase 4 `private-preview` |

## Project and monitoring lifecycle

1. Choose **Add Project** or press Command-N, then explicitly select a folder.
2. Select the project and enable it. Enabling preserves the user's preference but does not silently start monitoring.
3. Choose **Start Monitoring**. The state moves through Starting to Watching only after folder access and the FSEvents stream are active. Choose **Stop Monitoring** to cancel pending batches and release the stream and scoped access.
4. Connect a compatible LiveReload protocol-7 client to `ws://127.0.0.1:35729/livereload`. The Local Reload Server section distinguishes server startup, port conflict, no compatible clients, and the current compatible-client count.
5. Save a meaningful project file. Stylesheet-only batches request a live stylesheet refresh; HTML, JavaScript, mixed, and unknown supported changes request a full-page reload. Default and user-excluded files do not trigger a reload.
6. Choose **Reload Connected Browsers** for an explicit full-page reload when monitoring is active and at least one compatible client is connected.

Monitoring always starts from an explicit user action after launch. Runtime monitor, listener, pipeline, and browser-session state is memory-only and is never restored as active from the project configuration.

## Recovery and safety

Saved folder access is rechecked on every launch. If access becomes stale, missing, or denied, the project remains listed. Choose **Repair Access**, select the replacement folder, then retry monitoring; the project identity, name, and settings are retained. Root changes, dropped FSEvents, and stream failures stop the app from claiming that it is watching and expose a retry action.

A port conflict does not remove project configuration or stop folder monitoring. Free port 35729, then choose **Retry Server**. A malformed, oversized, slow, or disconnected browser is closed in isolation and does not stop other compatible clients. The server accepts loopback connections and loopback HTTP(S) browser origins only, expires incomplete negotiation, and does not serve the browser client script.

Recent activity is bounded and uses project-relative, length-limited summaries. It does not expose bookmark bytes, peer addresses, credentials, arbitrary absolute paths, or raw untrusted browser input. Long batches are summarized rather than rendered in full.

While a project mutation or runtime action is pending, conflicting controls for that project are disabled. Other projects remain independently selectable. Monitoring, server, recovery, and manual-reload controls are keyboard accessible, have VoiceOver labels and stable identifiers, and express state with text and symbols rather than colour alone.

Choose **Remove Project…** and confirm **Remove Configuration** to remove saved configuration and bookmark data. Source files are never deleted.
