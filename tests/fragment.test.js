// tests/fragment.test.js
import { describe, it, expect } from 'vitest';
import { parseFragment } from '../web/js/fragment.js';
import { validateState } from '../web/js/state.js';

// LSL builds: #v=1&q=<seq>&p=<0|1>&f=<0|1>&l=<0|1>&n=<name>&u=<url> (percent-encoded)
const good = '#v=1&q=7&p=1&f=0&l=1&n=Movies%20Night&u=https%3A%2F%2Fapp.kosmi.io%2Froom%2Fabc';

describe('parseFragment', () => {
  it('parses a well-formed fragment into a validatable raw state', () => {
    const raw = parseFragment(good);
    expect(raw).toEqual({
      seq: 7, power: 1, fs: 0, lock: 1, ch: 0,
      channels: [{ n: 'Movies Night', u: 'https://app.kosmi.io/room/abc' }],
    });
    expect(validateState(raw)).not.toBeNull();
  });
  it('accepts the fragment with or without the leading #', () => {
    expect(parseFragment(good.slice(1))).toEqual(parseFragment(good));
  });
  it('rejects empty, versionless, or wrong-version fragments', () => {
    expect(parseFragment('')).toBeNull();
    expect(parseFragment('#')).toBeNull();
    expect(parseFragment('#q=1&p=1&n=a&u=https%3A%2F%2Fx')).toBeNull();
    expect(parseFragment('#v=2&q=1&p=1&n=a&u=https%3A%2F%2Fx')).toBeNull();
  });
  it('rejects fragments missing the room url or with non-https url', () => {
    expect(parseFragment('#v=1&q=1&p=1&f=0&l=1&n=a')).toBeNull();
    expect(parseFragment('#v=1&q=1&p=1&f=0&l=1&n=a&u=http%3A%2F%2Fx')).toBeNull();
  });
  it('defaults missing flags safely (power on, fs off, locked)', () => {
    const raw = parseFragment('#v=1&q=3&n=a&u=https%3A%2F%2Fapp.kosmi.io%2Froom%2Fz');
    const s = validateState(raw);
    expect(s.power).toBe(1);
    expect(s.fs).toBe(0);
    expect(s.lock).toBe(1);
  });
});
