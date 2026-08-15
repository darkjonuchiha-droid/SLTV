// tests/sync.test.js
import { describe, it, expect, vi } from 'vitest';
import { createSync } from '../web/js/sync.js';

const STATE1 = { seq: 1, power: 1, ch: 0, fs: 0, lock: 1, channels: [{ n: 'A', u: 'https://a.example/x' }] };
const STATE2 = { ...STATE1, seq: 2, fs: 1 };

function jsonResponse(obj) {
  return { ok: true, json: async () => obj };
}

// fetchScript: array of functions(url) -> Promise<responseLike>; consumed in order,
// last entry repeats forever.
function scriptedFetch(script) {
  let i = 0;
  const calls = [];
  const fn = (url) => {
    calls.push(String(url));
    const step = script[Math.min(i, script.length - 1)];
    i++;
    return step(url);
  };
  fn.calls = calls;
  return fn;
}

describe('createSync', () => {
  it('fetches ?op=state first, delivers it, then long-polls with since=seq', async () => {
    const states = [];
    let resolvePoll;
    const fetchFn = scriptedFetch([
      async () => jsonResponse(STATE1),
      () => new Promise((r) => { resolvePoll = r; }),
    ]);
    const sync = createSync({ capUrl: 'https://cap.example/c', onState: (s) => states.push(s), fetchFn, minGapMs: 0 });
    sync.start();
    await vi.waitFor(() => expect(states).toEqual([STATE1]));
    await vi.waitFor(() => expect(fetchFn.calls.length).toBe(2));
    expect(fetchFn.calls[0]).toBe('https://cap.example/c?op=state');
    expect(fetchFn.calls[1]).toBe('https://cap.example/c?op=poll&since=1');
    resolvePoll(jsonResponse(STATE2));
    await vi.waitFor(() => expect(states).toEqual([STATE1, STATE2]));
    sync.stop();
  });

  it('ignores heartbeats (hb:1) and re-polls without delivering state', async () => {
    const states = [];
    let hbDone = false;
    const fetchFn = scriptedFetch([
      async () => jsonResponse(STATE1),
      async () => { hbDone = true; return jsonResponse({ seq: 1, hb: 1 }); },
      () => new Promise(() => {}),
    ]);
    const sync = createSync({ capUrl: 'https://cap.example/c', onState: (s) => states.push(s), fetchFn, minGapMs: 0 });
    sync.start();
    await vi.waitFor(() => expect(hbDone).toBe(true));
    await vi.waitFor(() => expect(fetchFn.calls.length).toBe(3));
    expect(states).toEqual([STATE1]);
    sync.stop();
  });

  it('reports reconnecting after 3 consecutive failures and ok on recovery', async () => {
    const statuses = [];
    const fetchFn = scriptedFetch([
      async () => { throw new Error('net'); },
      async () => { throw new Error('net'); },
      async () => { throw new Error('net'); },
      async () => jsonResponse(STATE1),
      () => new Promise(() => {}),
    ]);
    const sync = createSync({
      capUrl: 'https://cap.example/c', onState: () => {},
      onStatus: (s) => statuses.push(s), fetchFn, minGapMs: 0, backoffBaseMs: 1,
    });
    sync.start();
    await vi.waitFor(() => expect(statuses).toContain('reconnecting'));
    await vi.waitFor(() => expect(statuses[statuses.length - 1]).toBe('ok'));
    sync.stop();
  });

  it('drops invalid state payloads without calling onState', async () => {
    const states = [];
    let secondFetch = false;
    const fetchFn = scriptedFetch([
      async () => jsonResponse({ garbage: true }),
      async () => { secondFetch = true; return jsonResponse(STATE1); },
      () => new Promise(() => {}),
    ]);
    const sync = createSync({ capUrl: 'https://cap.example/c', onState: (s) => states.push(s), fetchFn, minGapMs: 0, backoffBaseMs: 1 });
    sync.start();
    await vi.waitFor(() => expect(secondFetch).toBe(true));
    await vi.waitFor(() => expect(states).toEqual([STATE1]));
    sync.stop();
  });
});
