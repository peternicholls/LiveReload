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
.build/debug/FSEventsPrototype repair-bookmark …          PASS (project identity retained; replacement restores)

Research/BrowserFixture
node --check server.mjs                                   PASS
```

The physical sleep/wake exercise passed on 2026-07-12; the sanitized capture is retained at `monitoring/sleep-wake-capture.log`.
