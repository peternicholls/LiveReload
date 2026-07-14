# Phase 2 production browser compatibility — 2026-07-14

**Evidence ID:** EV-P2-008  
**Task:** T030  
**Result:** PASS

## Scope

The accepted Phase 0 direct protocol fixture was run against the complete
Phase 2 production `LiveReloadCore.ReloadServer` path at
`127.0.0.1:35729/livereload`. The reusable Swift harness imports
`LiveReloadCore` and composes
`FSEventsFileEventSource` → `ProjectMonitor` → `ProjectPipeline` →
`ReloadServer`. The Node runner creates an ignored, workspace-backed
disposable project, edits its CSS and HTML files, and observes the resulting
browser behavior. Neither harness copies or reimplements the production
monitoring, batching, WebSocket, or LiveReload protocol behavior.

The fixture HTTP server remained on `127.0.0.1:35731`. Its separate research
WebSocket endpoint reported zero connected clients throughout both runs. An
additional raw connection completed a valid upgrade, sent an invalid unmasked
frame, and was closed before the file edits; both real browsers remained ready
and received the later reloads. These checks guard against validating the old
fixture server or proving browser and malformed-client behavior only in
separate test paths.

## Environment

- macOS 26.5.2 (25F84), arm64
- Node.js 26.5.0
- Safari 26.5.2 (21624.2.5.11.8), driven through SafariDriver
- Google Chrome 149.0.7827.201, run with its current headless implementation
- Apple Swift 6.2.4, package compiled with complete strict-concurrency checking

No browser profile, peer address beyond the fixed loopback endpoint, absolute
workspace path, process identifier, or volatile automation metadata is retained
in this record.

## Commands

From the repository root:

```sh
swift build --package-path Packages/LiveReloadCore -Xswiftc -warnings-as-errors
node --check Research/BrowserFixture/server.mjs
node --check Research/BrowserFixture/run-production-compatibility.mjs
node Research/BrowserFixture/run-production-compatibility.mjs
node Research/BrowserFixture/run-production-compatibility.mjs
```

The compatibility command creates temporary Chrome state, launches the
production server harness and loopback HTTP fixture, creates a SafariDriver
session, and cleans up every owned process and temporary profile on exit.

## Sanitized output

Both consecutive compatibility runs produced the same result:

```json
{
  "result": "PASS",
  "productionServer": "LiveReloadCore.ReloadServer",
  "endpoint": "127.0.0.1:35729/livereload",
  "protocol": 7,
  "browsers": {
    "Safari": "Included with Safari 26.5.2 (21624.2.5.11.8)",
    "Chromium": "Google Chrome 149.0.7827.201"
  },
  "readyClientCount": 2,
  "malformedThirdClientIsolated": true,
  "stylesheetReloads": {
    "Safari": 1,
    "Chromium": 1
  },
  "cacheBustedStylesheetRequests": {
    "Safari": 1,
    "Chromium": 1
  },
  "fullPageReloads": {
    "Safari": 1,
    "Chromium": 1
  },
  "postReloadProtocolHellos": {
    "Safari": 2,
    "Chromium": 2
  },
  "fixtureWebSocketClients": 0
}
```

The compatibility command was run again after loopback-Origin enforcement and
the bounded negotiation deadline were added. The same two-client stylesheet,
full-page, reconnect, and fixture-isolation result passed, proving that the
security hardening preserves current Safari and Chromium compatibility.

## Acceptance interpretation

- The CSS and HTML inputs were real writes beneath the disposable monitored
  root. Production FSEvents signals crossed the monitor, exclusion/batching,
  project-pipeline, and server boundaries; no harness command called
  `ReloadServer.broadcast` directly.
- Each browser sent the official protocol-7 client hello and acknowledged the
  production server hello. The production server reported exactly two ready
  clients before delivery.
- A third upgraded client sent an invalid unmasked browser frame and was
  isolated. Safari and Chromium remained ready and subsequently received both
  valid reload decisions, satisfying the two-browser isolation scenario.
- One stylesheet decision produced exactly one `styles.css` reload event per
  browser with `liveCSS=true`. Exactly one browser-labelled cache-busted
  stylesheet request followed in each client, proving both browsers applied the
  live stylesheet path.
- One full-page decision produced exactly one `index.html` reload event per
  browser with `liveCSS=false`. Each browser then loaded the fixture again and
  completed exactly one new protocol-7 hello.
- Both production broadcasts reported two sends and zero failures. The fixture
  WebSocket server retained a client count of zero.

## Limitations

- The fixture is a direct protocol-7 client. Browser-extension packaging and the
  maintained `livereload-js` bundle remain deferred to their planned phase.
- Chromium was exercised headlessly; Safari used the installed desktop browser
  through WebDriver. This is compatibility evidence for the recorded versions,
  not a claim about every historical browser release.
- The run validates real file-change monitoring, settlement, classification,
  negotiation, failure isolation, and reload delivery through the production
  local path. Build execution, remote-network exposure, and URL override are
  outside Phase 2 scope.
