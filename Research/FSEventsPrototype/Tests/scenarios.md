# FSEvents and Bookmark Prototype Scenarios

## Monitoring scenarios

| Scenario | Expected result |
|---|---|
| Create / modify / delete | A copied typed event names the watched root or changed path. |
| Rename within root | An event is emitted and the monitor stays live. |
| Root rename/removal | `rootChanged` or recovery-required output is emitted; monitor stops cleanly. |
| Dropped events | Simulated `mustScanSubDirs`, user-dropped, or kernel-dropped flags demand a full rescan. |
| Start / stop | Start succeeds once; stop releases the stream; repeated stop is safe. |
| Burst | A 10,000-write burst produces bounded event records and does not crash. |

## Bookmark scenarios

| Scenario | Expected result |
|---|---|
| Create | A selected or supplied directory produces a persisted bookmark file. |
| Restore | The bookmark resolves to a file URL and balances `startAccessingSecurityScopedResource` / stop. |
| Stale | Resolution reports `stale=true` without deleting the persisted project record. |
| Failure | A corrupt/missing bookmark returns a repair-required result. |
| Repair | `repair-bookmark PROJECT-ID FOLDER FILE` creates a replacement bookmark and emits the unchanged caller-provided project identity. |
