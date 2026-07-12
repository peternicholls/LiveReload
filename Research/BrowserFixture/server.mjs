import { createHash, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
const host = '127.0.0.1';
const port = Number(process.env.PORT ?? 35731);
const clients = new Set();
const events = [];

function record(event) {
  events.push({ at: new Date().toISOString(), ...event });
  if (events.length > 100) events.shift();
  process.stdout.write(`${JSON.stringify(event)}\n`);
}

function frame(text) {
  const data = Buffer.from(text);
  if (data.length >= 126) throw new Error('Fixture only supports short server frames');
  return Buffer.concat([Buffer.from([0x81, data.length]), data]);
}

function parseFrames(buffer) {
  const messages = [];
  let offset = 0;
  while (offset + 2 <= buffer.length) {
    const first = buffer[offset];
    const second = buffer[offset + 1];
    const masked = (second & 0x80) !== 0;
    let length = second & 0x7f;
    let headerLength = 2;
    if (length === 126) {
      if (offset + 4 > buffer.length) break;
      length = buffer.readUInt16BE(offset + 2);
      headerLength = 4;
    }
    const opcode = first & 0x0f;
    if (length === 127 || !masked || ![1, 8].includes(opcode)) {
      break;
    }
    const payloadOffset = offset + headerLength + 4;
    if (payloadOffset + length > buffer.length) break;
    const mask = buffer.subarray(offset + headerLength, payloadOffset);
    const payload = Buffer.from(buffer.subarray(payloadOffset, payloadOffset + length));
    for (let index = 0; index < payload.length; index += 1) payload[index] ^= mask[index % 4];
    messages.push({ opcode, payload: payload.toString('utf8') });
    offset = payloadOffset + length;
  }
  return { messages, remainder: buffer.subarray(offset) };
}

function broadcast(message) {
  const encoded = frame(JSON.stringify(message));
  for (const socket of clients) socket.write(encoded);
  record({ type: 'broadcast', message, clientCount: clients.size });
}

const server = createServer(async (request, response) => {
  const url = new URL(request.url, `http://${host}:${port}`);
  if (url.pathname === '/status') {
    response.setHeader('content-type', 'application/json');
    response.end(JSON.stringify({ clientCount: clients.size, events }));
    return;
  }
  if (url.pathname === '/trigger') {
    const path = url.searchParams.get('path') ?? '/styles.css';
    const liveCSS = url.searchParams.get('liveCSS') !== 'false';
    broadcast({ command: 'reload', path, liveCSS });
    response.setHeader('content-type', 'application/json');
    response.end(JSON.stringify({ ok: true, path, liveCSS }));
    return;
  }
  if (url.pathname === '/client-event') {
    record({
      type: 'client-event',
      browser: url.searchParams.get('browser') ?? 'unknown',
      event: url.searchParams.get('event') ?? 'unknown',
      path: url.searchParams.get('path') ?? null
    });
    response.statusCode = 204;
    response.end();
    return;
  }

  const relative = url.pathname === '/' ? '/index.html' : url.pathname;
  const resolved = normalize(join(root, relative));
  if (!resolved.startsWith(root) || !['.html', '.css', '.js'].includes(extname(resolved))) {
    response.statusCode = 404;
    response.end('Not found');
    return;
  }
  try {
    const content = await readFile(resolved);
    response.setHeader('content-type', extname(resolved) === '.css' ? 'text/css' : 'text/html');
    response.end(content);
  } catch {
    response.statusCode = 404;
    response.end('Not found');
  }
});

server.on('upgrade', (request, socket) => {
  if (request.url !== '/livereload' || request.headers.upgrade?.toLowerCase() !== 'websocket') {
    socket.destroy();
    return;
  }
  const key = request.headers['sec-websocket-key'];
  if (typeof key !== 'string') {
    socket.destroy();
    return;
  }
  const accept = createHash('sha1').update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`).digest('base64');
  socket.write([
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    `Sec-WebSocket-Accept: ${accept}`,
    '',
    ''
  ].join('\r\n'));
  clients.add(socket);
  record({ type: 'connected', clientCount: clients.size });
  let remainder = Buffer.alloc(0);
  socket.on('data', chunk => {
    const parsed = parseFrames(Buffer.concat([remainder, chunk]));
    remainder = parsed.remainder;
    for (const frameData of parsed.messages) {
      if (frameData.opcode === 8) {
        clients.delete(socket);
        socket.end();
        record({ type: 'disconnected', clientCount: clients.size });
        continue;
      }
      try {
        const message = JSON.parse(frameData.payload);
        record({ type: 'received', message });
        if (message.command === 'hello') {
          socket.write(frame(JSON.stringify({
            command: 'hello',
            protocols: ['http://livereload.com/protocols/official-7'],
            serverName: 'Phase 0 Browser Fixture'
          })));
        }
      } catch {
        record({ type: 'invalid-client-message' });
      }
    }
  });
  socket.on('close', () => {
    if (clients.delete(socket)) record({ type: 'disconnected', clientCount: clients.size });
  });
  socket.on('error', () => clients.delete(socket));
});

server.listen(port, host, () => record({ type: 'listening', host, port, instance: randomUUID() }));
