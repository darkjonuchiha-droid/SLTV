// tests/ui.test.js
// @vitest-environment jsdom
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { buildDom, applyState } from '../web/js/ui.js';
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

  it('setStatus shows and hides the reconnect overlay', () => {
    refs.setStatus('reconnecting');
    expect(refs.status.classList.contains('show')).toBe(true);
    refs.setStatus('ok');
    expect(refs.status.classList.contains('show')).toBe(false);
  });
});
