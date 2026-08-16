// web/js/ui.js — DOM construction and state application. No fetch, no polling.
import { computeEffects } from './state.js';

const OSD_MS = 4000;
const UNMUTE_GRACE_MS = 60000;
const GUIDE_MS = 30000;
const GUIDE_KEY = 'sltv.guided';
const ACCT_MS = 300000; // account mode auto-returns to the TV after 5 min
const KOSMI_HOME = 'https://app.kosmi.io/';

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
    '  <div id="acct" class="acct" title="Account">⚙</div>' +
    '  <div id="acct-panel" class="acct-panel">' +
    '<button id="acct-home">Kosmi Home — log in / out</button>' +
    '<button id="acct-back">Back to TV</button>' +
    '<button id="acct-reload">Reload screen</button>' +
    '</div>' +
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
  refs.acct = root.querySelector('#acct');
  refs.acctPanel = root.querySelector('#acct-panel');
  refs.acctHome = root.querySelector('#acct-home');
  refs.acctBack = root.querySelector('#acct-back');
  refs.acctReload = root.querySelector('#acct-reload');
  refs.override = false;   // account mode: this viewer is off the synced channel
  refs.lastState = null;
  refs.acctTimer = 0;
  refs.setStatus = (s) => refs.status.classList.toggle('show', s !== 'ok');

  // Per-viewer account panel: login/logout are cookie operations of THIS
  // instance only, so they must never ride the synced bus.
  refs.acct.addEventListener('click', () => refs.acctPanel.classList.toggle('show'));
  refs.acctHome.addEventListener('click', () => enterAccountMode(refs));
  refs.acctBack.addEventListener('click', () => exitAccountMode(refs));
  refs.acctReload.addEventListener('click', () => location.reload());
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
  if (refs.unlocked || refs.override) return; // interact mode / account mode: stays down
  refs.shield.classList.add('armed');
}

function enterAccountMode(refs) {
  refs.override = true;
  refs.acctPanel.classList.remove('show');
  refs.frame.src = KOSMI_HOME;
  lowerShield(refs);
  clearTimeout(refs.acctTimer);
  refs.acctTimer = setTimeout(() => exitAccountMode(refs), ACCT_MS);
}

function exitAccountMode(refs) {
  refs.acctPanel.classList.remove('show');
  if (!refs.override) return;
  refs.override = false;
  clearTimeout(refs.acctTimer);
  const st = refs.lastState;
  if (st) {
    refs.frame.src = st.power ? st.channels[st.ch].u : 'about:blank';
  }
  armShield(refs); // no-ops if the TV is unlocked
}

function lowerShield(refs) {
  clearTimeout(refs.shieldTimer);
  refs.shield.classList.remove('armed');
}

function resetShield(refs) {
  lowerShield(refs);
  if (refs.unlocked || refs.override) return;
  refs.shieldTimer = setTimeout(() => armShield(refs), UNMUTE_GRACE_MS);
}

export function handleWindowBlur(refs, activeEl) {
  if (refs.unlocked || refs.override) return;
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
  refs.lastState = next;
  refs.root.classList.toggle('off', !next.power);
  refs.root.classList.toggle('fullscreen', !!next.fs);
  refs.unlocked = !next.lock;
  if ((fx.powerChanged || fx.channelChanged) && refs.override) {
    // a synced change herds account-mode viewers back to the TV
    refs.override = false;
    clearTimeout(refs.acctTimer);
    refs.acctPanel.classList.remove('show');
  }
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
