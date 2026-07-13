# Data Model: Minimum Useful Reload Loop

## Persisted inputs retained from Phase 1

| Entity | Role in this feature | Invariants |
|---|---|---|
| `ProjectConfiguration` | Identifies the project and carries enabled state, bookmark reference, access state, and user ignore rules | Persistence remains owned by `ProjectStore`; no active runtime resource is persisted |
| `FolderReference` | Least-privilege access reference for the selected root | Bookmark bytes never enter diagnostics or UI |
| `IgnoreRule` | User-supplied exclusion pattern | Non-empty, bounded, matched only against normalized project-relative paths |
| `ActivityEvent` | Safe, bounded user-visible history | Summary remains redacted and does not retain full paths or client input |

## Runtime entities

| Entity | Attributes | Ownership and lifecycle |
|---|---|---|
| `MonitoringSession` | project ID, requested state, runtime state, recovery reason, start generation | `ProjectPipeline`; created only after explicit start and discarded after stop or app termination |
| `FileChangeSignal` | relative path or recovery marker, change kind, sequence/order metadata | Copied from the source callback into `ProjectMonitor`; Sendable and size-bounded |
| `ChangeBatch` | project ID, ordered de-duplicated relative paths, classification, received time | `ChangeBatcher`; one pending batch per project, cancelled on stop/recovery |
| `ExclusionPolicy` | built-in patterns, user rules, matching result | Immutable value used by the batcher; no raw root path retained |
| `BrowserConnection` | session ID, negotiation state, safe peer metadata, capability set | `ReloadServer`; removed on close or failure |
| `ServerState` | stopped, starting, listening, port conflict, failed, client count | `ReloadServer`; is not persisted and does not contain socket details in UI text |
| `ReloadDecision` | project ID, reason, full-page or stylesheet refresh, relative paths | `ProjectPipeline`; sent at most once per settled batch |

## State machines

### Monitoring session

```text
stopped → starting → watching
starting → failed
watching → stopping → stopped
watching → recovering
recovering → stopped
failed → stopped
```

- Repeated start while `starting` or `watching` is a no-op.
- Repeated stop while `stopped` or `stopping` is a no-op.
- Folder loss, root change, or event loss enters `recovering`, clears pending work, releases access, and cannot emit a reload.
- Explicit retry creates a fresh session generation only after access is valid.

### Browser connection

```text
connected → negotiating → ready → closing → closed
negotiating → rejected → closed
ready → failed → closed
```

- No reload is sent before a compatible negotiation completes.
- Invalid input, oversize input, or a write failure affects only the current connection.

### Reload decision

```text
signal → normalized → excluded | pending
pending → settled → stylesheet refresh | full page refresh
pending → stopped/recovering → discarded
```

## Identity and privacy rules

- Project ID is the sole cross-service project identity.
- Relative paths are retained only long enough to form a batch and safe summary; user-facing diagnostics summarize without full absolute roots.
- Browser sessions use generated identifiers rather than peer addresses in persisted events.
- Connection and monitor runtime state is never written to the project configuration file.
