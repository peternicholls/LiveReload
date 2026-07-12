import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { spawn } from 'node:child_process';
import net from 'node:net';
import { fileURLToPath } from 'node:url';

const executable = fileURLToPath(new URL('../.build/debug/WebSocketPrototype', import.meta.url));
const port = 35732;

function waitFor(child, pattern) {
  return new Promise((resolve, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error(`Timed out waiting for ${pattern}: ${output}`)), 5000);
    child.stdout.on('data', chunk => {
      output += chunk;
      if (pattern.test(output)) { clearTimeout(timer); resolve(); }
    });
    child.once('error', reject);
  });
}

function maskedFrame(message) {
  const data = Buffer.from(JSON.stringify(message));
  assert(data.length < 65536);
  const mask = randomBytes(4);
  const payload = Buffer.from(data);
  for (let index = 0; index < payload.length; index += 1) payload[index] ^= mask[index % 4];
  const header = data.length < 126
    ? Buffer.from([0x81, 0x80 | data.length])
    : Buffer.from([0x81, 0xfe, data.length >> 8, data.length & 0xff]);
  return Buffer.concat([header, mask, payload]);
}

function parseServerFrames(buffer) {
  const messages = [];
  let offset = 0;
  while (offset + 2 <= buffer.length) {
    let length = buffer[offset + 1] & 0x7f;
    let headerLength = 2;
    if (length === 126) {
      if (offset + 4 > buffer.length) break;
      length = buffer.readUInt16BE(offset + 2);
      headerLength = 4;
    } else if (length === 127) {
      break;
    }
    if (offset + headerLength + length > buffer.length) break;
    messages.push(JSON.parse(buffer.subarray(offset + headerLength, offset + headerLength + length).toString('utf8')));
    offset += headerLength + length;
  }
  return { messages, remainder: buffer.subarray(offset) };
}

function connectClient() {
  return new Promise((resolve, reject) => {
    const socket = net.connect(port, '127.0.0.1');
    let header = Buffer.alloc(0);
    let remainder = Buffer.alloc(0);
    const messages = [];
    socket.once('error', reject);
    socket.on('data', chunk => {
      if (header !== null) {
        header = Buffer.concat([header, chunk]);
        const split = header.indexOf('\r\n\r\n');
        if (split < 0) return;
        assert.match(header.subarray(0, split).toString('utf8'), /101 Switching Protocols/);
        remainder = header.subarray(split + 4);
        header = null;
      } else {
        remainder = Buffer.concat([remainder, chunk]);
      }
      const parsed = parseServerFrames(remainder);
      remainder = parsed.remainder;
      messages.push(...parsed.messages);
    });
    socket.once('connect', () => {
      const key = randomBytes(16).toString('base64');
      socket.write(`GET /livereload HTTP/1.1\r\nHost: 127.0.0.1:${port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ${key}\r\nSec-WebSocket-Version: 13\r\n\r\n`);
      const timer = setInterval(() => {
        if (header === null) {
          clearInterval(timer);
          resolve({ socket, messages, send: message => socket.write(maskedFrame(message)) });
        }
      }, 10);
    });
  });
}

async function waitForMessage(client, predicate) {
  for (let attempts = 0; attempts < 100; attempts += 1) {
    const found = client.messages.find(predicate);
    if (found) return found;
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  throw new Error('Timed out waiting for expected WebSocket message');
}

const server = spawn(executable, [String(port)], { stdio: ['pipe', 'pipe', 'pipe'] });
try {
  await waitFor(server, /^READY/m);
  const one = await connectClient();
  const two = await connectClient();
  const hello = { command: 'hello', protocols: ['http://livereload.com/protocols/official-7'], id: 'exercise', name: 'exercise', version: '1' };
  one.send(hello);
  two.send(hello);
  await waitForMessage(one, message => message.command === 'hello');
  await waitForMessage(two, message => message.command === 'hello');
  one.send({ broken: true });
  await new Promise(resolve => setTimeout(resolve, 100));
  server.stdin.write('{"command":"reload","path":"/fixture.css","liveCSS":true}\n');
  await waitForMessage(one, message => message.command === 'reload' && message.path === '/fixture.css');
  await waitForMessage(two, message => message.command === 'reload' && message.path === '/fixture.css');
  one.socket.end();
  two.socket.end();

  const collision = spawn(executable, [String(port)], { stdio: ['ignore', 'ignore', 'ignore'] });
  const collisionExit = await new Promise(resolve => collision.on('exit', resolve));
  assert.equal(collisionExit, 2);
  console.log('PASS bind hello reload multiple-clients malformed-input disconnect port-collision');
} finally {
  server.kill('SIGTERM');
}
