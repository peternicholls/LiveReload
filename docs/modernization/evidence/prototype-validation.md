# Combined Prototype Reproducibility Verdict

- **Task:** T038
- **Date:** 2026-07-12
- **Result:** PASS for clean Debug/Release builds and executable automated checks.

## Commands and results

```text
Research/WebSocketPrototype
swift package clean
swift build -Xswiftc -warnings-as-errors                  PASS
swift build -c release -Xswiftc -warnings-as-errors       PASS
node scripts/exercise.mjs                                 PASS bind hello reload multiple-clients malformed-input disconnect port-collision

Research/FSEventsPrototype
swift package clean
swift build -Xswiftc -warnings-as-errors                  PASS
swift build -c release -Xswiftc -warnings-as-errors       PASS
.build/debug/FSEventsPrototype simulate-recovery          PASS (RECOVERY-REQUIRED)

Research/BrowserFixture
node --check server.mjs                                   PASS
```

The FSEvents physical sleep/wake manual exercise remains ISS-003; it does not invalidate the reproducibility of the harnesses or the accepted Phase 0 architecture decision.
