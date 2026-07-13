# Physical Sleep/Wake Monitoring Procedure

**Task:** T036 / ISS-003
**Purpose:** validate one real system sleep/wake cycle without asserting that a simulation proves operating-system wake delivery.

1. From `Research/FSEventsPrototype`, create a disposable workspace-backed directory, for example `mkdir -p SleepWakeFixture`.
2. Start the capture script:

   ```text
   scripts/sleep-wake-capture.sh "$PWD/SleepWakeFixture" ../../../docs/modernization/evidence/monitoring/sleep-wake-capture.log
   ```

3. Put the Mac to sleep using the normal system control, then wake and unlock it.
4. Create or modify `SleepWakeFixture/after-wake.txt` before the 120-second capture window expires.
5. Inspect the capture file. It must contain at least one `EVENT` after wake and a `STOPPED` line; record the exact result in `fsevents-bookmark-prototype.md` and the Sprint 0 review.

If no event arrives, retain the capture log, update ISS-003, and do not check T036 complete.
