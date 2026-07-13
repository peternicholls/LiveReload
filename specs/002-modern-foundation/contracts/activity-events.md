# Activity Events Contract

## Categories and severities

Categories are fixed: `app`, `storage`, `folderAccess`, `monitoring`, `network`, `build`, and `pipeline`. Severities are fixed: `debug`, `info`, `warning`, and `error`.

## Required behavior

- Every event has stable ID, timestamp, category, severity, redacted summary, and optional project ID.
- Events must be redacted before they enter memory, logs, or persistence. No raw URL path, bookmark bytes, source content, command arguments, credentials, environment values, or unbounded underlying error description is allowed.
- The in-app history holds the newest 200 events; appending event 201 removes the oldest event.
- OSLog categories map one-to-one to the fixed event categories, preserving privacy interpolation for any platform log payload.
- UI shows a safe summary and recovery action where one exists; it does not require a debugger to understand common persistence/access failures.

## Test obligations

Tests assert category/severity validity, capacity trimming, path redaction, long-message bounding, and absence of secret-like fixture values from snapshots.
