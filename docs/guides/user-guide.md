# Modern LiveReload User Guide

## Status

The modern application is not released. Phase 1 is establishing the native project lifecycle only; filesystem monitoring, browser reload, and build execution are not available yet.

## Supported behavior table

| Capability | Status | Evidence / next owner |
|---|---|---|
| Add, restore, rename, enable, repair, and remove projects | planned for Phase 1 | `specs/002-modern-foundation/spec.md` |
| Filesystem monitoring | deferred | Phase 2 `reload-loop` |
| Browser reload server | deferred | Phase 2 `reload-loop` |
| Build commands | deferred | Phase 3 `developer-workflow` |
| Public distribution | deferred | Phase 4 `private-preview` |

Do not use this guide to infer unsupported behavior. Each completed user-facing capability must add setup, normal flow, failure/recovery, accessibility, and limitation guidance before it is advertised as supported.
