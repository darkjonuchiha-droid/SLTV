// mock/mock-lp-server.mjs — simulates the prim's HTTP-in endpoint locally.
// GET /cap/test            → bootstrap html (like the LSL serves in-world)
// GET /cap/test?op=state   → state JSON
// GET /cap/test?op=poll&since=N → held ≤15 s, answered on change or heartbeat
// Static /web/* from ./web. stdin commands: power | fs | ch <n> | help
// Dev-only extra (NOT part of the LSL contract): GET /cap/test?op=cmd&do=power|fs
// or ?op=cmd&do=ch&n=<idx> — lets tests/tools drive state without stdin.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import process from 'node:process';

const PORT = 8787;
const PAGE_BASE = `http://localhost:${PORT}/web`;
const state = {
  seq: 1, power: 1, ch: 0, fs: 0,
  channels: [
    { n: 'Movies Night', u: 'https://app.kosmi.io/room/replace-me' },
    { n: 'Music Hall', u: 'https://app.kosmi.io/room/replace-me-too' },
  ],
};
let waiters = []; // {res, timer}

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' };

const bootstrap = `<!DOCTYPE html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<link rel="stylesheet" href="${PAGE_BASE}/css/tv.css"></head>
<body><script type="module" src="${PAGE_BASE}/js/main.js"></script></body></html>`;

function stateJson() { return JSON.stringify(state); }

function broadcast() {
  state.seq++;
  for (const w of waiters) { clearTimeout(w.timer); w.res.end(stateJson()); }
  waiters = [];
  console.log('[mock] broadcast', stateJson());
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  res.setHeader('Cache-Control', 'no-store');
  if (url.pathname === '/cap/test') {
    const op = url.searchParams.get('op');
    if (!op) { res.setHeader('Content-Type', 'text/html'); return res.end(bootstrap); }
    res.setHeader('Content-Type', 'application/json');
    if (op === 'state') return res.end(stateJson());
    if (op === 'poll') {
      const since = Number(url.searchParams.get('since') ?? -1);
      if (since !== state.seq) return res.end(stateJson());
      const timer = setTimeout(() => {
        waiters = waiters.filter((w) => w.res !== res);
        res.end(JSON.stringify({ seq: state.seq, hb: 1 }));
      }, 15000);
      waiters.push({ res, timer });
      return;
    }
    if (op === 'cmd') { // dev-only remote control, mirrors the stdin commands
      const doCmd = url.searchParams.get('do');
      if (doCmd === 'power') { state.power = state.power ? 0 : 1; broadcast(); }
      else if (doCmd === 'fs') { state.fs = state.fs ? 0 : 1; broadcast(); }
      else if (doCmd === 'ch') { state.ch = Math.min(Math.max(Number(url.searchParams.get('n')) || 0, 0), state.channels.length - 1); broadcast(); }
      return res.end(stateJson());
    }
    res.statusCode = 400; return res.end('{}');
  }
  if (url.pathname.startsWith('/web/')) {
    const rel = normalize(url.pathname.slice('/web/'.length)).replace(/^([.][.][\\/])+/, '');
    try {
      const body = await readFile(join('web', rel));
      res.setHeader('Content-Type', MIME[extname(rel)] ?? 'application/octet-stream');
      return res.end(body);
    } catch {
      res.statusCode = 404; return res.end('not found');
    }
  }
  res.statusCode = 404; res.end('not found');
});

server.listen(PORT, () => {
  console.log(`[mock] TV page:  http://localhost:${PORT}/cap/test`);
  console.log('[mock] commands: power | fs | ch <n>');
});

process.stdin.setEncoding('utf8');
process.stdin.on('data', (line) => {
  const [cmd, arg] = line.trim().split(/\s+/);
  if (cmd === 'power') { state.power = state.power ? 0 : 1; broadcast(); }
  else if (cmd === 'fs') { state.fs = state.fs ? 0 : 1; broadcast(); }
  else if (cmd === 'ch') { state.ch = Math.min(Math.max(Number(arg) || 0, 0), state.channels.length - 1); broadcast(); }
  else console.log('[mock] commands: power | fs | ch <n>');
});
