# Clean-Account / First-Launch Smoke

Required disposable-folder flow:

1. Launch with no configuration and verify the accessible empty/add state.
2. Add a disposable empty folder; rename and toggle enabled state.
3. Relaunch and confirm identity/settings restore once.
4. Exercise missing/repair state and select a replacement disposable folder.
5. Remove configuration and confirm both disposable folders remain on disk.

Automated core tests pass identity/settings retention, repair replacement, missing-state preservation, and folder-preserving removal. Five XCUITest scenarios exercised the actual app/store lifecycle using newly created temporary folders and persistent test storage. The run verified first-launch loading/empty states, add, relaunch restoration, rename/toggle, missing-folder repair, corrupt-store recovery, future-version write protection, long-label/reduced-motion layout, confirmed removal copy, and on-disk source-folder preservation.

Result: **PASS** — 4 UI tests, 0 failures. No private source folder or retained absolute path was used.
