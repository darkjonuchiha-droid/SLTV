// web/js/sync.js — long-poll client against the prim's HTTP-in cap URL.
// Contract: GET ?op=state → full state; GET ?op=poll&since=N → state | {hb:1}.
import { validateState } from './state.js';

export function createSync({
  capUrl,
  onState,
  onStatus,
  fetchFn = (...a) => fetch(...a),
  stateTimeoutMs = 10000,
  pollTimeoutMs = 30000,   // LSL heartbeats at ~15 s; this is the safety abort
  minGapMs = 500,          // never hammer the sim faster than this
  backoffBaseMs = 1000,
  backoffMaxMs = 5000,
  failuresBeforeWarn = 3,
}) {
  let seq = -1;
  let stopped = false;
  let failures = 0;

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  async function getJson(url, timeoutMs) {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      const res = await fetchFn(url, { signal: ctrl.signal });
      if (!res.ok) throw new Error('http ' + res.status);
      return await res.json();
    } finally {
      clearTimeout(t);
    }
  }

  async function loop() {
    while (!stopped) {
      const startedAt = Date.now();
      try {
        const data = seq < 0
          ? await getJson(capUrl + '?op=state', stateTimeoutMs)
          : await getJson(capUrl + '?op=poll&since=' + seq, pollTimeoutMs);
        failures = 0;
        onStatus?.('ok');
        if (!data?.hb) {
          const state = validateState(data);
          if (state && state.seq !== seq) {
            seq = state.seq;
            onState(state);
          } else if (!state) {
            throw new Error('invalid state payload');
          }
        }
      } catch (err) {
        failures++;
        if (failures >= failuresBeforeWarn) onStatus?.('reconnecting');
        await sleep(Math.min(backoffBaseMs * 2 ** (failures - 1), backoffMaxMs));
      }
      const elapsed = Date.now() - startedAt;
      if (elapsed < minGapMs) await sleep(minGapMs - elapsed);
    }
  }

  return {
    start() { loop(); },
    stop() { stopped = true; },
  };
}
