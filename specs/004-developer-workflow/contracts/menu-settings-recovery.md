# Menu, Settings, and Recovery Contract

## Menu-bar commands

The menu exposes overall health, active projects, connected browser count, pause/resume, manual reload, open window, and quit. Commands route to the same gated app-model intents used by the main window. Each command has a keyboard equivalent, an accessibility label, and a non-color-only state cue.

## Settings

Global settings expose port, debounce, activity-history limit, default exclusions, and launch behavior. Each field validates before persistence, reports its correction, and supports reset to safe defaults. Per-project exclusions provide a match preview over relative paths and show rule precedence.

## Recovery

Known folder, port, sleep/wake/path, and build failures retain project configuration, identify what stopped, and offer repair, retry, correction, or open-settings actions. Recovery summaries redact environment values, credentials, absolute paths, and unrelated source contents. Repeated recovery commands do not duplicate listeners, monitors, or processes.
