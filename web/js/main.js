// web/js/main.js — wiring. The page is served FROM the cap URL (or index.html
// locally / mock), so the cap endpoint is simply our own origin+path, no query.
import { buildDom, applyState } from './ui.js';
import { createSync } from './sync.js';

const capUrl = location.origin + location.pathname;
let root = document.getElementById('app');
if (!root) { // bootstrap page from the prim has an empty body
  root = document.createElement('div');
  root.id = 'app';
  document.body.appendChild(root);
}
const refs = buildDom(root);

let prev = null;
const sync = createSync({
  capUrl,
  onState(next) { applyState(refs, prev, next); prev = next; },
  onStatus(s) { refs.setStatus(s); },
});
sync.start();
