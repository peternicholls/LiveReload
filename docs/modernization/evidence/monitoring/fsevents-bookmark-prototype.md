# FSEvents and Bookmark Prototype Evidence

- **Tasks:** T032–T038
- **Date:** 2026-07-12
- **Host:** Apple silicon macOS 26.5.2

## Build verification

```text
swift build -Xswiftc -warnings-as-errors
Build complete!
```

## Monitoring results

| Scenario | Result |
|---|---|
| Workspace create / modify / rename / delete | Passed; file-path events emitted and monitor stopped with count 3. |
| Root rename/removal | Passed; watched root produced `recovery=true` events, then the monitor stopped cleanly. |
| Dropped-event recovery | Passed deterministically through `simulate-recovery`, which combines `mustScanSubDirs` and `rootChanged` and yields `RECOVERY-REQUIRED`. |
| 10,000 writes | Passed; 10,000 appends to one workspace file resulted in six bounded event records and no crash. |
| Start / stop | Passed; each run emitted `STARTED`, completed, and emitted `STOPPED`. |
| `/tmp` watch | No events observed in this host environment; not used as a production-test fixture. |
| Physical sleep/wake | Not invoked because putting the shared desktop to sleep would interrupt the active session. Lifecycle safety was exercised by stop/restart and root-change recovery; a physical sleep/wake test remains a Phase 4 release validation item. |

## Bookmark results

```text
BOOKMARK-CREATED
BOOKMARK-RESTORED stale=false access=true path=FixtureRoot

BOOKMARK-CREATED
BOOKMARK-RESTORED stale=true access=true path=Renamed

FAILED The file couldn’t be opened because it isn’t in the correct format.
```

The final failure is the intentional corrupt-bookmark test. The moving-folder result preserves access while reporting `stale=true`, so the production UI must request repair/re-save rather than delete the project.

## Result

The Phase 2 architecture may use direct FSEvents with a callback adapter and security-scoped bookmarks with explicit stale/repair state. See ADR-002.
