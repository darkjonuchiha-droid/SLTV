// web/js/fragment.js — parses the TV state the LSL pushes via the media URL's
// #fragment. Wire format (values percent-encoded by llEscapeURL):
//   #v=1&q=<seq>&p=<0|1>&f=<0|1>&l=<0|1>&n=<channel name>&u=<room url>
// Returns a raw-state object shaped for validateState (single-channel), or null.

export function parseFragment(hash) {
  if (!hash) return null;
  const params = new URLSearchParams(hash.startsWith('#') ? hash.slice(1) : hash);
  if (params.get('v') !== '1') return null;
  const u = params.get('u');
  if (!u || !u.startsWith('https://')) return null;
  const flag = (name, dflt) => {
    const v = params.get(name);
    if (v === null) return dflt;
    return v === '1' ? 1 : 0;
  };
  return {
    seq: Number(params.get('q') ?? 0),
    power: flag('p', 1),
    fs: flag('f', 0),
    lock: flag('l', 1),
    ch: 0,
    channels: [{ n: params.get('n') ?? '', u }],
  };
}
