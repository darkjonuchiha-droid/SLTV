// web/js/main.js — wiring. The TV state arrives in the URL #fragment, written
// by the LSL via the media URL (PRIM_MEDIA_CURRENT_URL). If the viewer treats
// fragment-only changes as same-document navigation we get instant hashchange
// sync; if it reloads instead, the boot path below re-reads the same state.
// Either way, no requests to the prim — it never has to serve anything.
import { buildDom, applyState } from './ui.js';
import { parseFragment } from './fragment.js';
import { validateState } from './state.js';

let root = document.getElementById('app');
if (!root) {
  root = document.createElement('div');
  root.id = 'app';
  document.body.appendChild(root);
}
const refs = buildDom(root);

let prev = null;
function applyFromHash() {
  const state = validateState(parseFragment(location.hash));
  refs.setStatus(state ? 'ok' : 'nosignal');
  if (!state) return;
  if (prev && state.seq === prev.seq) return; // duplicate of the current broadcast
  applyState(refs, prev, state);
  prev = state;
}
window.addEventListener('hashchange', applyFromHash);
applyFromHash();
