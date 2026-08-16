// web/js/ui.js — DOM construction and state application. No fetch, no polling.
import { computeEffects } from './state.js';

const OSD_MS = 4000;
const UNMUTE_GRACE_MS = 60000;
const GUIDE_MS = 30000;
const GUIDE_KEY = 'sltv.guided';

export function buildDom(root) {
  root.innerHTML =
    '<div id="tv" class="tv">' +
    '  <div class="bezel">' +
    '    <iframe id="frame" src="about:blank" allow="autoplay; fullscreen; encrypted-media; microphone; camera; display-capture"></iframe>' +
    '    <div id="shield" class="shield"></div>' +
    '    <div id="idle" class="idle"><div class="idle-logo">SLTV</div><div class="idle-sub">powered off</div></div>' +
    '  </div>' +
    '  <div id="osd" class="osd"></div>' +
    '  <div id="status" class="status">no signal</div>' +
    '  <div id="guide" class="guide"><div class="guide-card">' +
    '<b>Welcome to SLTV</b>' +
    '<span>▶ No sound or picture? Click the screen once.</span>' +
    '<span>🔊 Volume: your viewer’s media slider (only affects you).</span>' +
    '<button id="guide-ok">Got it</button>' +
    '</div></div>' +
    '</div>';
  const refs = {
    root: root.querySelector('#tv'),
    frame: root.querySelector('#frame'),
    shield: root.querySelector('#shield'),
    idle: root.querySelector('#idle'),
    osd: root.querySelector('#osd'),
    status: root.querySelector('#status'),
    osdTimer: 0,
    shieldTimer: 0,
  };
  refs.guide = root.querySelector('#guide');
  refs.guideOk = root.querySelector('#guide-ok');
  refs.setStatus = (s) => refs.status.classList.toggle('show', s !== 'ok');
  // Clicking into the (cross-origin) iframe blurs the top window — that is the
  // watcher's unmute click; afterwards the screen goes inert to hover/clicks.
  window.addEventListener('blur', () => handleWindowBlur(refs, document.activeElement));

  // One-time setup card per viewer (no chat spam). CEF may block storage.
  let guided = false;
  try { guided = localStorage.getItem(GUIDE_KEY) === '1'; } catch (e) {}
  if (!guided) {
    refs.guide.classList.add('show');
    const guideTimer = setTimeout(() => refs.guide.classList.remove('show'), GUIDE_MS);
    refs.guideOk.addEventListener('click', () => {
      clearTimeout(guideTimer);
      refs.guide.classList.remove('show');
      try { localStorage.setItem(GUIDE_KEY, '1'); } catch (e) {}
    });
  }
  return refs;
}

function armShield(refs) {
  clearTimeout(refs.shieldTimer);
  if (refs.unlocked) return; // owner has Interact mode on: shield stays down
  refs.shield.classList.add('armed');
}

function lowerShield(refs) {
  clearTimeout(refs.shieldTimer);
  refs.shield.classList.remove('armed');
}

function resetShield(refs) {
  lowerShield(refs);
  if (refs.unlocked) return;
  refs.shieldTimer = setTimeout(() => armShield(refs), UNMUTE_GRACE_MS);
}

export function handleWindowBlur(refs, activeEl) {
  if (refs.unlocked) return;
  if (activeEl === refs.frame) armShield(refs);
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
  refs.unlocked = !next.lock;
  if (fx.lockChanged && prev) {
    if (next.lock) armShield(refs);  // re-lock: instant, no grace
    else lowerShield(refs);
  }
  if (fx.powerChanged || fx.channelChanged) {
    if (next.power) {
      const chan = next.channels[next.ch];
      refs.frame.src = chan.u;
      if (fx.channelChanged && prev) showOsd(refs, chan.n);
      resetShield(refs); // fresh room content may need a fresh unmute click
    } else {
      refs.frame.src = 'about:blank'; // actually stops Kosmi audio
    }
  }
}
