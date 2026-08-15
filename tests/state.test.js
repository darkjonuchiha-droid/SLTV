// tests/state.test.js
import { describe, it, expect } from 'vitest';
import { validateState, computeEffects } from '../web/js/state.js';

const goodRaw = {
  seq: 3, power: 1, ch: 1, fs: 0,
  channels: [
    { n: 'Movies', u: 'https://app.kosmi.io/room/aaa' },
    { n: 'Music', u: 'https://app.kosmi.io/room/bbb' },
  ],
};

describe('validateState', () => {
  it('accepts a well-formed state', () => {
    const s = validateState(goodRaw);
    expect(s).toEqual(goodRaw);
  });
  it('rejects null, non-objects, missing seq, missing channels', () => {
    expect(validateState(null)).toBeNull();
    expect(validateState('x')).toBeNull();
    expect(validateState({ channels: [] })).toBeNull();
    expect(validateState({ seq: 1 })).toBeNull();
  });
  it('drops malformed and non-https channels; rejects if none survive', () => {
    const s = validateState({ ...goodRaw, channels: [
      { n: 'ok', u: 'https://x.example/room' },
      { n: 'bad-proto', u: 'http://x.example' },
      { u: 'https://no-name.example' },
      null,
    ]});
    expect(s.channels).toEqual([{ n: 'ok', u: 'https://x.example/room' }]);
    expect(validateState({ ...goodRaw, channels: [{ n: 'b', u: 'http://x' }] })).toBeNull();
  });
  it('clamps ch into range and normalizes power/fs to 0|1', () => {
    const s = validateState({ ...goodRaw, ch: 99, power: true, fs: 'yes' });
    expect(s.ch).toBe(1);
    expect(s.power).toBe(1);
    expect(s.fs).toBe(1);
    expect(validateState({ ...goodRaw, ch: -5 }).ch).toBe(0);
  });
});

describe('computeEffects', () => {
  const s = validateState(goodRaw);
  it('first state (prev=null) triggers everything', () => {
    expect(computeEffects(null, s)).toEqual({ channelChanged: true, powerChanged: true, fsChanged: true });
  });
  it('no change → no effects', () => {
    expect(computeEffects(s, { ...s })).toEqual({ channelChanged: false, powerChanged: false, fsChanged: false });
  });
  it('detects channel index change and same-index url change', () => {
    expect(computeEffects(s, { ...s, ch: 0 }).channelChanged).toBe(true);
    const swapped = { ...s, channels: [s.channels[0], { n: 'Music', u: 'https://app.kosmi.io/room/ccc' }] };
    expect(computeEffects(s, swapped).channelChanged).toBe(true);
  });
  it('detects power and fs changes', () => {
    expect(computeEffects(s, { ...s, power: 0 }).powerChanged).toBe(true);
    expect(computeEffects(s, { ...s, fs: 1 }).fsChanged).toBe(true);
  });
});
