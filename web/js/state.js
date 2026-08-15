// web/js/state.js — pure state validation and diffing. No DOM, no fetch.

export function validateState(raw) {
  if (!raw || typeof raw !== 'object') return null;
  if (typeof raw.seq !== 'number' || !Array.isArray(raw.channels)) return null;
  const channels = raw.channels.filter(
    (c) => c && typeof c.n === 'string' && typeof c.u === 'string' && c.u.startsWith('https://')
  ).map((c) => ({ n: c.n, u: c.u }));
  if (channels.length === 0) return null;
  const chRaw = typeof raw.ch === 'number' ? Math.trunc(raw.ch) : 0;
  return {
    seq: raw.seq,
    power: raw.power ? 1 : 0,
    fs: raw.fs ? 1 : 0,
    // locked unless the TV explicitly says 0 — old TVs without the field stay locked
    lock: raw.lock === 0 ? 0 : 1,
    ch: Math.min(Math.max(chRaw, 0), channels.length - 1),
    channels,
  };
}

export function computeEffects(prev, next) {
  if (!prev) return { channelChanged: true, powerChanged: true, fsChanged: true, lockChanged: true };
  return {
    channelChanged: prev.ch !== next.ch || prev.channels[prev.ch]?.u !== next.channels[next.ch]?.u,
    powerChanged: prev.power !== next.power,
    fsChanged: prev.fs !== next.fs,
    lockChanged: prev.lock !== next.lock,
  };
}
