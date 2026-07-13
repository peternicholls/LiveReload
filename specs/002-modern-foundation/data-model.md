# Data Model: Modern Foundation

## Configuration envelope

`ConfigurationEnvelope` is the persisted top-level record.

| Field | Type / rule | Purpose |
|---|---|---|
| `schemaVersion` | positive integer; current value defined in code | Select migration/rejection behavior |
| `projects` | ordered collection of `ProjectConfiguration` | User-managed project list |
| `createdAt`, `updatedAt` | ISO-8601 timestamps | Safe diagnostics and change evidence |

Unknown future `schemaVersion` values are rejected without overwriting the source file. Missing data produces an empty envelope. Corrupt data is quarantined and surfaced as a redacted activity event.

## Project configuration

| Field | Type / rule | Purpose |
|---|---|---|
| `id` | UUID; immutable after creation | Stable identity across rename/repair |
| `displayName` | trimmed non-empty string; bounded length | User-visible project name |
| `isEnabled` | Boolean | Future monitoring eligibility placeholder |
| `folderReference` | bookmark data + redacted display metadata | Least-privilege selected folder reference |
| `folderAccessState` | derived, non-authoritative runtime state | Available / needs repair / missing / denied |
| `buildConfiguration` | validated non-executable placeholder | Future build configuration boundary |
| `ignoreRules` | validated non-executable placeholder collection | Future filter boundary |
| `monitoringState` | disabled/not-started placeholder | Explicitly prevents Phase 1 monitoring claims |

Invariant: two records must not refer to the same normalized folder identity. Repair changes `folderReference` and its derived state only; it does not change `id`, `displayName`, `isEnabled`, build configuration, or ignore rules.

## Folder access state machine

```text
new selection ──► available
                     │ resolve stale / missing / denied
                     ▼
               needsRepair ── repair cancelled ──► needsRepair
                     │ repair succeeds
                     ▼
                 available
```

The state machine never transitions from a failure to deletion. Removal is a separate confirmed user action that affects configuration only.

## Activity event

| Field | Rule |
|---|---|
| `id` | UUID |
| `timestamp` | creation time |
| `category` | app, storage, folderAccess, monitoring, network, build, or pipeline |
| `severity` | debug, info, warning, error |
| `summary` | redacted, bounded user/actionable text |
| `projectID` | optional stable identity; never folder path |

`ActivityStore` retains the newest 200 events. Redaction occurs before construction; raw underlying errors, full paths, environment values, bookmark bytes, and file contents never enter the event.

## Service ownership

| Owner | Isolation | Mutable state |
|---|---|---|
| `ProjectStore` | actor | current envelope and serialized writes |
| `ActivityStore` | actor | bounded event buffer |
| `AppModel` | `@MainActor` | view selection, presentation alerts, task handles |
| `FolderAccessProvider` | protocol implementation | scoped access token lifecycle; real adapter is not shared mutable UI state |
