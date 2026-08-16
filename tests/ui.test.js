// tests/ui.test.js
// @vitest-environment jsdom
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { buildDom, applyState, handleWindowBlur } from '../web/js/ui.js';
import { validateState } from '../web/js/state.js';

const base = validateState({
  seq: 1, power: 1, ch: 0, fs: 0,
  channels: [
    { n: 'Movies', u: 'https://app.kosmi.io/room/aaa' },
    { n: 'Music', u: 'https://app.kosmi.io/room/bbb' },
  ],
});

describe('ui', () => {
  let refs;
  beforeEach(() => {
    document.body.innerHTML = '<div id="app"></div>';
    refs = buildDom(document.getElementById('app'));
  });

  it('buildDom creates frame, idle screen, osd, and status overlay', () => {
    expect(refs.frame.tagName).toBe('IFRAME');
    expect(refs.frame.getAttribute('allow')).toContain('autoplay');
    expect(refs.idle).toBeTruthy();
    expect(refs.osd).toBeTruthy();
    expect(refs.status).toBeTruthy();
  });

  it('first state sets iframe src to current channel', () => {
    applyState(refs, null, base);
    expect(refs.frame.src).toBe('https://app.kosmi.io/room/aaa');
    expect(refs.root.classList.contains('off')).toBe(false);
  });

  it('heartbeat-equal state does NOT touch iframe src (no reload)', () => {
    applyState(refs, null, base);
    refs.frame.src = 'https://app.kosmi.io/room/aaa#marker';
    applyState(refs, base, { ...base, seq: 2 });
    expect(refs.frame.src).toBe('https://app.kosmi.io/room/aaa#marker');
  });

  it('channel change swaps src and shows OSD with channel name', () => {
    vi.useFakeTimers();
    applyState(refs, null, base);
    applyState(refs, base, { ...base, seq: 2, ch: 1 });
    expect(refs.frame.src).toBe('https://app.kosmi.io/room/bbb');
    expect(refs.osd.textContent).toBe('Music');
    expect(refs.osd.classList.contains('show')).toBe(true);
    vi.advanceTimersByTime(4001);
    expect(refs.osd.classList.contains('show')).toBe(false);
    vi.useRealTimers();
  });

  it('power off blanks the iframe and shows idle; power on restores channel', () => {
    applyState(refs, null, base);
    const off = { ...base, seq: 2, power: 0 };
    applyState(refs, base, off);
    expect(refs.frame.src).toBe('about:blank');
    expect(refs.root.classList.contains('off')).toBe(true);
    applyState(refs, off, { ...off, seq: 3, power: 1 });
    expect(refs.frame.src).toBe('https://app.kosmi.io/room/aaa');
    expect(refs.root.classList.contains('off')).toBe(false);
  });

  it('fullscreen toggles the fullscreen class', () => {
    applyState(refs, null, base);
    applyState(refs, base, { ...base, seq: 2, fs: 1 });
    expect(refs.root.classList.contains('fullscreen')).toBe(true);
    applyState(refs, { ...base, fs: 1 }, { ...base, seq: 3, fs: 0 });
    expect(refs.root.classList.contains('fullscreen')).toBe(false);
  });

  it('login mode starts nav-cropped; the chip toggles it; leaving resets it', () => {
    const login = { ...base, seq: 2, channels: [{ n: 'Kosmi Login', u: 'https://app.kosmi.io/' }], ch: 0 };
    applyState(refs, null, login);
    expect(refs.root.classList.contains('login')).toBe(true);
    expect(refs.root.classList.contains('navshow')).toBe(false);
    refs.navToggle.dispatchEvent(new Event('click'));
    expect(refs.root.classList.contains('navshow')).toBe(true);
    refs.navToggle.dispatchEvent(new Event('click'));
    expect(refs.root.classList.contains('navshow')).toBe(false);
    refs.navToggle.dispatchEvent(new Event('click')); // leave it shown...
    applyState(refs, login, { ...base, seq: 3 });     // ...then exit login mode
    expect(refs.root.classList.contains('navshow')).toBe(false);
  });

  it('Kosmi non-room pages get the narrow-column class; rooms never do', () => {
    applyState(refs, null, base); // base channels are /room/ URLs
    expect(refs.root.classList.contains('login')).toBe(false);
    const login = { ...base, seq: 2, channels: [{ n: 'Kosmi Login', u: 'https://app.kosmi.io/' }], ch: 0 };
    applyState(refs, base, login);
    expect(refs.root.classList.contains('login')).toBe(true);
    const other = { ...base, seq: 3, channels: [{ n: 'X', u: 'https://app.kosmi.io/payment' }], ch: 0 };
    applyState(refs, login, other);
    expect(refs.root.classList.contains('login')).toBe(true);
    applyState(refs, other, { ...base, seq: 4 });
    expect(refs.root.classList.contains('login')).toBe(false);
  });

  it('setStatus shows and hides the reconnect overlay', () => {
    refs.setStatus('reconnecting');
    expect(refs.status.classList.contains('show')).toBe(true);
    refs.setStatus('ok');
    expect(refs.status.classList.contains('show')).toBe(false);
  });
});

describe('pointer shield', () => {
  let refs;
  beforeEach(() => {
    vi.useFakeTimers();
    document.body.innerHTML = '<div id="app"></div>';
    refs = buildDom(document.getElementById('app'));
  });

  it('exists and starts unarmed (grace window for the unmute click)', () => {
    applyState(refs, null, base);
    expect(refs.shield).toBeTruthy();
    expect(refs.shield.classList.contains('armed')).toBe(false);
  });

  it('arms when the watcher clicks into the iframe (window blur to frame)', () => {
    applyState(refs, null, base);
    handleWindowBlur(refs, refs.frame);
    expect(refs.shield.classList.contains('armed')).toBe(true);
  });

  it('does not arm on blur to something other than the frame', () => {
    applyState(refs, null, base);
    handleWindowBlur(refs, document.body);
    expect(refs.shield.classList.contains('armed')).toBe(false);
  });

  it('arms by itself after the grace period (autoplay-without-click case)', () => {
    applyState(refs, null, base);
    vi.advanceTimersByTime(60001);
    expect(refs.shield.classList.contains('armed')).toBe(true);
  });

  it('re-opens the grace window on channel change and power-on', () => {
    applyState(refs, null, base);
    handleWindowBlur(refs, refs.frame);
    expect(refs.shield.classList.contains('armed')).toBe(true);
    const next = { ...base, seq: 2, ch: 1 };
    applyState(refs, base, next);
    expect(refs.shield.classList.contains('armed')).toBe(false);
    handleWindowBlur(refs, refs.frame);
    const off = { ...next, seq: 3, power: 0 };
    applyState(refs, next, off);
    const on = { ...off, seq: 4, power: 1 };
    applyState(refs, off, on);
    expect(refs.shield.classList.contains('armed')).toBe(false);
  });

  it('fullscreen toggle alone does NOT re-open the grace window', () => {
    applyState(refs, null, base);
    handleWindowBlur(refs, refs.frame);
    applyState(refs, base, { ...base, seq: 2, fs: 1 });
    expect(refs.shield.classList.contains('armed')).toBe(true);
  });

  it('unlock drops the shield and keeps it down (blur, timer, channel change)', () => {
    applyState(refs, null, base);
    handleWindowBlur(refs, refs.frame);
    expect(refs.shield.classList.contains('armed')).toBe(true);
    const unlocked = { ...base, seq: 2, lock: 0 };
    applyState(refs, base, unlocked);
    expect(refs.shield.classList.contains('armed')).toBe(false);
    handleWindowBlur(refs, refs.frame);
    expect(refs.shield.classList.contains('armed')).toBe(false);
    vi.advanceTimersByTime(60001);
    expect(refs.shield.classList.contains('armed')).toBe(false);
    const chSwitch = { ...unlocked, seq: 3, ch: 1 };
    applyState(refs, unlocked, chSwitch);
    vi.advanceTimersByTime(60001);
    expect(refs.shield.classList.contains('armed')).toBe(false);
  });

  it('re-locking arms the shield immediately (no grace window)', () => {
    const unlocked = { ...base, lock: 0 };
    applyState(refs, null, unlocked);
    expect(refs.shield.classList.contains('armed')).toBe(false);
    applyState(refs, unlocked, { ...unlocked, seq: 2, lock: 1 });
    expect(refs.shield.classList.contains('armed')).toBe(true);
  });

  it('initial state already unlocked starts with the shield down', () => {
    applyState(refs, null, { ...base, lock: 0 });
    vi.advanceTimersByTime(60001);
    expect(refs.shield.classList.contains('armed')).toBe(false);
  });
});

describe('first-visit guide', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    localStorage.clear();
    document.body.innerHTML = '<div id="app"></div>';
  });

  it('shows on a fresh viewer', () => {
    const refs = buildDom(document.getElementById('app'));
    expect(refs.guide.classList.contains('show')).toBe(true);
  });

  it('stays hidden when the viewer was already guided', () => {
    localStorage.setItem('sltv.guided', '1');
    const refs = buildDom(document.getElementById('app'));
    expect(refs.guide.classList.contains('show')).toBe(false);
  });

  it('"Got it" hides it and sets the flag', () => {
    const refs = buildDom(document.getElementById('app'));
    refs.guideOk.dispatchEvent(new Event('click'));
    expect(refs.guide.classList.contains('show')).toBe(false);
    expect(localStorage.getItem('sltv.guided')).toBe('1');
  });

  it('auto-hides after 30 s without setting the flag', () => {
    const refs = buildDom(document.getElementById('app'));
    vi.advanceTimersByTime(30001);
    expect(refs.guide.classList.contains('show')).toBe(false);
    expect(localStorage.getItem('sltv.guided')).toBeNull();
  });
});
