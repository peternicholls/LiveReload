# Menu, Settings, and Recovery Contract

## Menu-bar commands

The menu exposes overall health, active projects, connected browser count, pause/resume, **Reload Now**, open window, and quit. Commands route to the same gated app-model intents used by the main window. **Reload Now** is labelled as an immediate build-gate bypass and leaves active and pending build batches unchanged. Each command has a keyboard equivalent, an accessibility label, and a non-color-only state cue.

## Settings

Global settings expose loopback port (default `35729`, range `1024...65535`), debounce (default `250 ms`, range `100...500 ms`), activity-history limit (default `200`, range `50...500`), an empty custom global-exclusion list, and launch behavior (`showMainWindow` or `menuBarOnly`, default `showMainWindow`). Launch behavior controls presentation after user-initiated launch only; it does not register a login item, start the server, or restore monitoring. Fixed built-in exclusions apply first, custom global patterns second, and per-project patterns third; any match excludes and preview identifies the matching layer/rule. A confirmation-backed reset restores scalar defaults and clears custom global patterns without changing fixed built-ins, project configuration, or per-project patterns. Lowering the history cap immediately retains only the newest allowed events.

## Recovery

Known folder, port, sleep/wake, network/path-transition, and build failures retain project configuration, identify what stopped, and offer repair, retry, correction, or open-settings actions. Recovery summaries redact environment values, credentials, absolute paths, and unrelated source contents. Repeated recovery commands do not duplicate listeners, monitors, process groups, or pending builds.
