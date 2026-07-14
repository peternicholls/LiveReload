# Phase 2 Acceptance Quickstart

## Prerequisites

- Apple-silicon Mac running macOS 15 or newer.
- Xcode 26.3-compatible Swift 6.2 toolchain and an Apple Development signing identity.
- The Phase 0 disposable browser fixture for Safari and Chromium.
- A disposable workspace project; do not use private source folders for evidence capture.

## Verification sequence

1. Run the feature's core unit and integration tests with warnings treated as errors.
2. Build the app in Debug and Release, then run app and UI tests through `scripts/verify-modern.sh` after its Phase 2 gates are added.
3. Add a disposable project, explicitly start monitoring, and confirm the `Watching` state and local server connection state.
4. Connect the Safari and Chromium fixtures to the local endpoint and confirm the compatible client count.
5. Save a CSS file, then an HTML file. Verify one settled stylesheet refresh and one settled full-page refresh respectively.
6. Exercise default exclusions, a user exclusion, a mixed burst, repeated start/stop, root removal, lost-event recovery, and a port conflict. Confirm every failure preserves configuration and exposes the matching recovery state.
7. Start the release-built idle probe with one production project monitor and local server. After its 30-second warm-up, collect that owning process's CPU value once per second for five minutes. Record the mean and peak with resource-cleanup evidence, without retaining absolute paths, browser peer addresses, or private source contents.

## Expected results

- The browser receives exactly one appropriate reload per settled meaningful batch.
- Excluded paths and stopped/recovering projects send no reload.
- Browser, folder, and stream failures isolate their own resources and leave unrelated projects and clients usable.
- The five-minute idle sample has a mean CPU below 1%; its recorded peak makes transient work visible for review.
- The documented Phase 2 test, browser, privacy, and release gates pass before completion is claimed.
