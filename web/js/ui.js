// web/js/ui.js — DOM construction and state application. No fetch, no polling.
import { computeEffects } from './state.js';

const OSD_MS = 4000;

export function buildDom(root) {
  root.innerHTML =
    '<div id="tv" class="tv">' +
    '  <div class="bezel">' +
    '    <iframe id="frame" src="about:blank" allow="autoplay; fullscreen; encrypted-media; microphone; camera; display-capture"></iframe>' +
    '    <div id="idle" class="idle"><div class="idle-logo">SLTV</div><div class="idle-sub">powered off</div></div>' +
    '  </div>' +
    '  <div id="osd" class="osd"></div>' +
    '  <div id="status" class="status">reconnecting…</div>' +
    '</div>';
  const refs = {
    root: root.querySelector('#tv'),
    frame: root.querySelector('#frame'),
    idle: root.querySelector('#idle'),
    osd: root.querySelector('#osd'),
    status: root.querySelector('#status'),
    osdTimer: 0,
  };
  refs.setStatus = (s) => refs.status.classList.toggle('show', s !== 'ok');
  return refs;
}

function showOsd(refs, text) {
  refs.osd.textContent = text;
  refs.osd.classList.add('show');
  clearTimeout(refs.osdTimer);
  refs.osdTimer = setTimeout(() => refs.osd.classList.remove('show'), OSD_MS);
}

export function applyState(refs, prev, next) {
  const fx = computeEffects(prev, next);
  refs.root.classList.toggle('off', !next.power);
  refs.root.classList.toggle('fullscreen', !!next.fs);
  if (fx.powerChanged || fx.channelChanged) {
    if (next.power) {
      const chan = next.channels[next.ch];
      refs.frame.src = chan.u;
      if (fx.channelChanged && prev) showOsd(refs, chan.n);
    } else {
      refs.frame.src = 'about:blank'; // actually stops Kosmi audio
    }
  }
}
