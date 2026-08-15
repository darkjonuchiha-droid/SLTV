// mock/serve.mjs — minimal static server for local development of the shell.
// The TV state is driven by editing the URL fragment (see web/js/fragment.js),
// e.g.: http://localhost:8787/web/index.html#v=1&q=1&p=1&f=0&l=1&n=Test&u=https%3A%2F%2Fapp.kosmi.io%2Froom%2Fx
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const PORT = 8787;
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png' };

http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  res.setHeader('Cache-Control', 'no-store');
  if (!url.pathname.startsWith('/web/')) { res.statusCode = 404; return res.end('use /web/index.html'); }
  const rel = normalize(url.pathname.slice('/web/'.length)).replace(/^([.][.][\\/])+/, '');
  try {
    const body = await readFile(join('web', rel));
    res.setHeader('Content-Type', MIME[extname(rel)] ?? 'application/octet-stream');
    res.end(body);
  } catch {
    res.statusCode = 404;
    res.end('not found');
  }
}).listen(PORT, () => console.log(`[serve] http://localhost:${PORT}/web/index.html#v=1&q=1&p=1&n=Test&u=...`));
