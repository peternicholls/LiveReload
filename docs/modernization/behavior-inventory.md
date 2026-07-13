# LiveReload Behavior Inventory

**Phase:** 0 — Discovery baseline
**Status:** In progress
**Baseline tag:** `phase-0-baseline-upstream-develop-af9b5ce8`
**Upstream baseline:** `af9b5ce8d5cf1f7065b8e70e4ddff8bce6963633` (`develop`, 2016-07-03)
**Rule:** A `v1` record needs at least one cited evidence source and a named future verification method. Source evidence, direct runtime observation, and inference are labelled separately.

## Record format

| Field | Requirement |
|---|---|
| ID | Stable `BEH-NNN` identifier |
| Actor | User, browser client, filesystem, build tool, or app |
| Preconditions / action / outcome | Observable behavior only |
| Evidence | Repository reference, test, runtime observation, or primary source |
| Classification | `v1`, `deferred`, or `rejected` |
| Future verification | Named unit, integration, UI, end-to-end, or manual check |
| Notes | Limitations, conflicts, or inference |

## Records

| ID | Actor | Observable behavior | Evidence | Classification | Future verification | Notes |
|---|---|---|---|---|---|---|
| BEH-001 | User / workspace | Adding a project normalizes `~`, standardizes and resolves symlinks; an existing normalized path is reused rather than duplicated. Removing a project stops its monitoring before removing it from the workspace. | `mac/Classes/Model/Workspace.m:163-194` | v1 | `ProjectStore` duplicate-normalization integration test; project-removal monitor-stop test | The modern app will use file identity/bookmarks where available rather than exact legacy string semantics. |
| BEH-002 | User / persistence | Project state restores a security-scoped bookmark when possible, falls back to a stored path, and recreates a project only for a file URL. | `mac/Classes/Model/Workspace.m:133-152` | v1 | Bookmark create/restore/stale/repair integration tests | The fallback must not bypass current least-privilege rules. |
| BEH-003 | User / app | A project tracks accessible and exists states; it starts security-scoped access when needed, creates its monitor only once accessible, and saves after access is newly restored. | `mac/Classes/Model/Project/Project.m:330-357` | v1 | Folder-access adapter unit tests; permission-loss/repair UI test | The modern state model will expose recovery rather than use legacy KVO. |
| BEH-004 | User / workspace | Monitoring is enabled through named requests; each project runs only while at least one request exists, and enabling triggers a complete reanalysis. | `mac/Classes/Model/Workspace.m:201-212`; `mac/Classes/Model/Project/Project.m:420-452` | v1 | `ProjectMonitor` start/stop idempotency and first-scan integration tests | Browser-connection coupling is not retained; user start/stop is the modern control. |
| BEH-005 | User / filesystem | Monitoring filters by enabled extensions, excluded names, and per-project excluded paths; hidden files are deliberately not blanket-filtered. | `mac/Classes/Model/Project/Project.m:400-415`; `mac/Classes/Model/Project/Project.m:855-879` | v1 | Ignore-rule unit suite, including dotfiles and exclusion precedence | The exact legacy extension/plugin model is deferred; user ignore behavior is retained. |
| BEH-006 | Filesystem / app | FSEvents paths are cached, debounced, rescanned through a tree differ, and delegated only when the calculated change set is nonempty; explicit rescan adds the root path. | `mac/FileSystemMonitoringKit/FileSystemMonitoringKit/FSMonitor.m:183-227`; callback `:246-249` | v1 | Fake-clock debounce tests; temporary-directory FSEvents create/modify/rename/delete/rescan tests | Historical FSEvents corruption workaround is rejected; current dropped/root-change recovery is separately researched. |
| BEH-007 | Filesystem / build | A detected file-change batch starts or reuses a build, analyzes changed paths, adds files, and starts execution. | `mac/Classes/Model/Project/Project.m:487-509` | v1 | `ProjectPipeline` change-to-build/reload integration test | Legacy compiler-analysis pipeline is deferred in favor of structured user build commands. |
| BEH-008 | Build / app | A build deduplicates modified files, prevents concurrent target execution, absorbs newly arriving changes before finish, and waits briefly before marking completion. | `LRActionKit/Source/Build/LRBuild.swift:55-74`; `:149-199` | v1 | Pipeline actor tests for coalescing, single active build, and one follow-up batch | Exact grace intervals are not compatibility requirements. |
| BEH-009 | Build / user | Failed compiler operations are surfaced with source/output context; successful output hides an existing error view. | `mac/Classes/Model/Project/Project.m:540-551` | deferred | Future build-output/activity-log acceptance specification | V1 retains bounded build output and error state, not legacy compiler-specific UI. |
| BEH-010 | Build / browser | A completed build derives reload requests from modified files, excludes compiler inputs until their outputs change, then emits reload messages only after build finish. | `mac/LRActionKit/LRActionKit/Build/LRBuild.swift:74-111`; `mac/Classes/Model/Project/Project.m:526-537` | v1 | Build success/failure and reload-suppression end-to-end tests | Generic command execution replaces legacy action rules. |
| BEH-011 | Browser client / server | A client must send `hello` with a protocols array; protocol 7 accepts `reload` with required string `path` and optional `liveCSS`, `originalPath`, and `overrideURL`. Invalid JSON, commands, attributes, or no negotiated protocol are protocol errors. | `node_modules/livereload-protocol/lib/parser.coffee:18-80`; `:117-178` | v1 | Pure Swift protocol golden-fixture tests; raw WebSocket integration test | Only the standard monitoring protocol is v1; saving and URL override are deferred. |
| BEH-012 | Browser server / user | The browser server listens, reports port occupation rather than crashing, tracks connection count, broadcasts reload messages to monitoring clients, and closes on disposal. | `node_modules/livereload-service-server/src/server.coffee:14-80`; `test/server_test.coffee:14-38` | v1 | Loopback listener integration tests for port conflict, multiple clients, reload broadcast, and clean shutdown | Serving historical `livereload.js` and URL override are deferred. |

## Runtime observation status

The archived Intel application is **not executed in this session**. The Phase 0 constitution requires static inspection, hash/signature capture, a disposable account or isolated environment, no private mounts/credentials, restricted networking, and stop conditions. Those isolation prerequisites are unavailable to this noninteractive workspace, so source and test evidence are used instead. See `ISS-001`.
