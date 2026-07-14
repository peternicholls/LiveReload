import { spawn, spawnSync } from 'node:child_process';
import { EventEmitter } from 'node:events';
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { connect } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';

const repositoryRoot = fileURLToPath(new URL('../..', import.meta.url));
const fixtureURL = client => `http://127.0.0.1:35731/?wsPort=35729&client=${client}`;
const fixtureStatusURL = 'http://127.0.0.1:35731/status';
const safariDriverURL = 'http://127.0.0.1:4444';
const chromeBinary = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const children = [];
let safariSession;
let chromeProfile;
let browserWorkspace;

function start(command, args, options = {}) {
  const child = spawn(command, args, {
    cwd: repositoryRoot,
    stdio: ['pipe', 'pipe', 'pipe'],
    ...options
  });
  child.stderrText = '';
  child.stderr.on('data', chunk => {
    child.stderrText = `${child.stderrText}${chunk}`.slice(-8_000);
  });
  children.push(child);
  return child;
}

function jsonLines(child) {
  const events = new EventEmitter();
  const lines = createInterface({ input: child.stdout });
  lines.on('line', line => {
    try {
      events.emit('event', JSON.parse(line));
    } catch {
      // Build tooling can write non-JSON progress; only harness records are relevant.
    }
  });
  return events;
}

function waitForHarness(events, predicate, label, timeout = 60_000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      events.off('event', listener);
      reject(new Error(`Timed out waiting for ${label}`));
    }, timeout);
    const listener = event => {
      if (!predicate(event)) return;
      clearTimeout(timer);
      events.off('event', listener);
      resolve(event);
    };
    events.on('event', listener);
  });
}

async function requestJSON(url, options = {}) {
  const response = await fetch(url, {
    signal: AbortSignal.timeout(5_000),
    ...options
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${options.method ?? 'GET'} ${new URL(url).pathname} failed (${response.status}): ${JSON.stringify(body)}`);
  }
  return body;
}

async function waitFor(label, predicate, timeout = 45_000) {
  const deadline = Date.now() + timeout;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const value = await predicate();
      if (value) return value;
    } catch (error) {
      lastError = error;
    }
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  throw new Error(`Timed out waiting for ${label}${lastError ? `: ${lastError.message}` : ''}`);
}

function browserFamily(userAgent) {
  if (/Chrome\//.test(userAgent)) return 'Chromium';
  if (/Safari\//.test(userAgent) && !/Chrome\//.test(userAgent)) return 'Safari';
  return 'Unknown';
}

function clientEvents(status, event, path, liveCSS) {
  return status.events.filter(candidate =>
    candidate.type === 'client-event'
      && candidate.event === event
      && (path === undefined || candidate.path === path)
      && (liveCSS === undefined || candidate.liveCSS === liveCSS)
  );
}

function assertFamilies(events, label, expectedPerFamily) {
  const counts = { Safari: 0, Chromium: 0 };
  for (const event of events) {
    const family = browserFamily(event.browser);
    if (family in counts) {
      if (event.client !== family) {
        throw new Error(`${label}: ${family} event used unexpected client label ${event.client}`);
      }
      counts[family] += 1;
    }
  }
  for (const [family, count] of Object.entries(counts)) {
    if (count !== expectedPerFamily) {
      throw new Error(`${label}: expected ${expectedPerFamily} ${family} event(s), received ${count}`);
    }
  }
  return counts;
}

async function createSafariSession() {
  const body = await requestJSON(`${safariDriverURL}/session`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ capabilities: { alwaysMatch: { browserName: 'safari' } } })
  });
  const sessionID = body.value?.sessionId ?? body.sessionId;
  if (!sessionID) throw new Error('SafariDriver did not return a session identifier');
  safariSession = sessionID;
  await requestJSON(`${safariDriverURL}/session/${sessionID}/url`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ url: fixtureURL('Safari') })
  });
}

async function cleanup() {
  if (safariSession) {
    await fetch(`${safariDriverURL}/session/${safariSession}`, {
      method: 'DELETE',
      signal: AbortSignal.timeout(3_000)
    }).catch(() => {});
    safariSession = undefined;
  }
  for (const child of children.reverse()) {
    if (child.exitCode === null) child.kill('SIGTERM');
  }
  await Promise.all(children.map(child => new Promise(resolve => {
    if (child.exitCode !== null) return resolve();
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      resolve();
    }, 3_000);
    child.once('exit', () => {
      clearTimeout(timer);
      resolve();
    });
  })));
  if (chromeProfile) await rm(chromeProfile, { recursive: true, force: true });
  if (browserWorkspace) await rm(browserWorkspace, { recursive: true, force: true });
}

async function exerciseMalformedThirdClient() {
  await new Promise((resolve, reject) => {
    const socket = connect({ host: '127.0.0.1', port: 35729 });
    let response = '';
    let malformedFrameSent = false;
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error('Malformed third client was not isolated within five seconds'));
    }, 5_000);
    socket.on('connect', () => {
      socket.write([
        'GET /livereload HTTP/1.1',
        'Host: 127.0.0.1:35729',
        'Upgrade: websocket',
        'Connection: Upgrade',
        'Origin: http://127.0.0.1:35731',
        'Sec-WebSocket-Version: 13',
        'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==',
        '',
        ''
      ].join('\r\n'));
    });
    socket.on('data', chunk => {
      response += chunk.toString('latin1');
      if (!malformedFrameSent && response.includes('\r\n\r\n')) {
        if (!response.startsWith('HTTP/1.1 101')) {
          clearTimeout(timer);
          socket.destroy();
          reject(new Error(`Malformed third client was not upgraded: ${response.split('\r\n')[0]}`));
          return;
        }
        malformedFrameSent = true;
        socket.write(Buffer.from([0x81, 0x01, 0x7b])); // Unmasked browser text frame.
      }
    });
    socket.on('close', () => {
      clearTimeout(timer);
      if (!malformedFrameSent) {
        reject(new Error('Malformed third client closed before the invalid frame was sent'));
      } else {
        resolve();
      }
    });
    socket.on('error', error => {
      clearTimeout(timer);
      reject(error);
    });
  });
}

async function main() {
  const safariVersion = spawnSync('/usr/bin/safaridriver', ['--version'], { encoding: 'utf8' }).stdout.trim();
  const chromeVersionResult = spawnSync(chromeBinary, ['--version'], { encoding: 'utf8' });
  if (chromeVersionResult.status !== 0) throw new Error('Google Chrome is not installed at the expected application path');
  const chromeVersion = chromeVersionResult.stdout.trim();

  const workspaceParent = join(repositoryRoot, '.build', 'browser-evidence');
  await mkdir(workspaceParent, { recursive: true });
  browserWorkspace = await mkdtemp(join(workspaceParent, 'workspace-'));
  await writeFile(join(browserWorkspace, 'styles.css'), 'body { color: black; }\n');
  await writeFile(join(browserWorkspace, 'index.html'), '<!doctype html><title>Fixture</title>\n');

  const productionServer = start('swift', [
    'run',
    '--package-path', 'Packages/LiveReloadCore',
    'LiveReloadBrowserHarness',
    '--port', '35729',
    '--root', browserWorkspace
  ]);
  const harnessEvents = jsonLines(productionServer);
  const listening = await waitForHarness(
    harnessEvents,
    event => event.event === 'listening' || event.event === 'startup-failed',
    'production ReloadServer startup'
  );
  if (listening.event !== 'listening') throw new Error(`Production ReloadServer failed to start (${listening.phase})`);

  const fixture = start(process.execPath, ['Research/BrowserFixture/server.mjs'], {
    env: { ...process.env, PORT: '35731' }
  });
  await waitFor('HTTP browser fixture', () => requestJSON(fixtureStatusURL));

  const safariDriver = start('/usr/bin/safaridriver', ['--port', '4444']);
  await waitFor('SafariDriver', async () => {
    const response = await fetch(`${safariDriverURL}/status`, { signal: AbortSignal.timeout(1_000) });
    return response.ok;
  });
  await createSafariSession();

  chromeProfile = await mkdtemp(join(tmpdir(), 'livereload-browser-'));
  start(chromeBinary, [
    '--headless=new',
    '--disable-gpu',
    '--no-first-run',
    '--no-default-browser-check',
    `--user-data-dir=${chromeProfile}`,
    fixtureURL('Chromium')
  ]);

  const initialStatus = await waitFor('protocol-7 hello from Safari and Chromium', async () => {
    const status = await requestJSON(fixtureStatusURL);
    const hellos = clientEvents(status, 'hello');
    const families = new Set(hellos.map(event => browserFamily(event.browser)));
    return families.has('Safari') && families.has('Chromium') ? status : undefined;
  });
  if (initialStatus.clientCount !== 0) {
    throw new Error('Fixture WebSocket server was used; production-path evidence is invalid');
  }
  assertFamilies(clientEvents(initialStatus, 'hello'), 'Initial protocol hello', 1);

  const readyPromise = waitForHarness(harnessEvents, event => event.event === 'status', 'two ready production clients');
  productionServer.stdin.write('status\n');
  const ready = await readyPromise;
  if (ready.phase !== 'listening' || ready.readyClientCount !== 2) {
    throw new Error(`Expected two ready production clients, received ${ready.readyClientCount ?? 0}`);
  }

  await exerciseMalformedThirdClient();
  const isolationPromise = waitForHarness(harnessEvents, event => event.event === 'status', 'valid clients after malformed third');
  productionServer.stdin.write('status\n');
  const isolated = await isolationPromise;
  if (isolated.phase !== 'listening' || isolated.readyClientCount !== 2) {
    throw new Error(`Malformed third client disrupted the two ready browsers (${isolated.readyClientCount ?? 0} remain)`);
  }

  const stylesheetBroadcastPromise = waitForHarness(
    harnessEvents,
    event => event.event === 'broadcast' && event.mode === 'stylesheet',
    'stylesheet file-change broadcast',
    10_000
  );
  await writeFile(join(browserWorkspace, 'styles.css'), 'body { color: rebeccapurple; }\n');
  const stylesheetBroadcast = await stylesheetBroadcastPromise;
  const stylesheetStatus = await waitFor('one stylesheet reload per browser', async () => {
    const status = await requestJSON(fixtureStatusURL);
    return clientEvents(status, 'reload', 'styles.css', true).length === 2
      && status.events.filter(event => event.type === 'stylesheet-request' && event.cacheBusted).length === 2
      ? status
      : undefined;
  });
  const stylesheetCounts = assertFamilies(
    clientEvents(stylesheetStatus, 'reload', 'styles.css', true),
    'Stylesheet reload',
    1
  );
  if (stylesheetBroadcast.sentCount !== 2 || stylesheetBroadcast.failedCount !== 0) {
    throw new Error('Production stylesheet broadcast did not reach both ready clients exactly once');
  }
  const stylesheetRequests = Object.fromEntries(['Safari', 'Chromium'].map(client => [
    client,
    stylesheetStatus.events.filter(event =>
      event.type === 'stylesheet-request' && event.cacheBusted && event.client === client
    ).length
  ]));
  if (stylesheetRequests.Safari !== 1 || stylesheetRequests.Chromium !== 1) {
    throw new Error(`Expected one cache-busted stylesheet request per browser, received ${JSON.stringify(stylesheetRequests)}`);
  }

  const pageBroadcastPromise = waitForHarness(
    harnessEvents,
    event => event.event === 'broadcast' && event.mode === 'full-page',
    'HTML file-change broadcast',
    10_000
  );
  await writeFile(join(browserWorkspace, 'index.html'), '<!doctype html><title>Updated fixture</title>\n');
  const pageBroadcast = await pageBroadcastPromise;
  const finalStatus = await waitFor('one full-page reload and reconnect per browser', async () => {
    const status = await requestJSON(fixtureStatusURL);
    return clientEvents(status, 'reload', 'index.html', false).length === 2
      && clientEvents(status, 'hello').length === 4
      ? status
      : undefined;
  });
  const pageCounts = assertFamilies(
    clientEvents(finalStatus, 'reload', 'index.html', false),
    'Full-page reload',
    1
  );
  assertFamilies(clientEvents(finalStatus, 'hello'), 'Protocol hello including reconnect', 2);
  if (pageBroadcast.sentCount !== 2 || pageBroadcast.failedCount !== 0) {
    throw new Error('Production full-page broadcast did not reach both ready clients exactly once');
  }
  if (finalStatus.clientCount !== 0) {
    throw new Error('Fixture WebSocket server was used; production-path evidence is invalid');
  }

  const stoppedPromise = waitForHarness(harnessEvents, event => event.event === 'stopped', 'production server shutdown');
  productionServer.stdin.write('stop\n');
  await stoppedPromise;

  process.stdout.write(`${JSON.stringify({
    result: 'PASS',
    productionServer: 'LiveReloadCore.ReloadServer',
    endpoint: '127.0.0.1:35729/livereload',
    protocol: 7,
    browsers: {
      Safari: safariVersion,
      Chromium: chromeVersion
    },
    readyClientCount: ready.readyClientCount,
    malformedThirdClientIsolated: true,
    stylesheetReloads: stylesheetCounts,
    cacheBustedStylesheetRequests: stylesheetRequests,
    fullPageReloads: pageCounts,
    postReloadProtocolHellos: { Safari: 2, Chromium: 2 },
    fixtureWebSocketClients: finalStatus.clientCount
  }, null, 2)}\n`);
}

try {
  await main();
} catch (error) {
  process.stderr.write(`Browser compatibility run failed: ${error.message}\n`);
  const failed = children.find(child => child.exitCode && child.exitCode !== 0);
  if (failed?.stderrText) process.stderr.write(`${failed.stderrText}\n`);
  process.exitCode = 1;
} finally {
  await cleanup();
}
