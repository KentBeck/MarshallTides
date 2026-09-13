import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sunTimes, moonTimes, moonIllumination, moonPhaseName } from '../src/astro.js';
import { fmtTime, fromWall } from '../src/time.js';
import { STATION } from '../src/tides.js';

const { lat, lng } = STATION;
const day = fromWall(2026, 9, 13, 12);

// Reference times from a published almanac for Marshall. The algorithm is
// good to a few minutes, which is all a widget needs.
const near = (actual, y, m, d, h, mi, tolMin) => {
  const want = fromWall(y, m, d, h, mi);
  assert.ok(Math.abs(actual - want) <= tolMin * 60e3, `${fmtTime(actual)} not within ${tolMin}m of ${fmtTime(want)}`);
};

test('sun times for Marshall, 13-14 Sep 2026', () => {
  const s13 = sunTimes(day, lat, lng);
  near(s13.sunrise, 2026, 9, 13, 6, 53, 3);
  near(s13.sunset, 2026, 9, 13, 19, 22, 3);
  const s14 = sunTimes(fromWall(2026, 9, 14, 12), lat, lng);
  near(s14.sunrise, 2026, 9, 14, 6, 53, 3);
});

test('moon times for Marshall, 13-14 Sep 2026', () => {
  const m13 = moonTimes(day, lat, lng);
  near(m13.set, 2026, 9, 13, 20, 28, 10);
  const m14 = moonTimes(fromWall(2026, 9, 14, 12), lat, lng);
  near(m14.rise, 2026, 9, 14, 10, 44, 3);
});

test('moon is a young waxing crescent on 13 Sep 2026', () => {
  const i = moonIllumination(day);
  assert.ok(i.phase > 0.03 && i.phase < 0.12, `phase ${i.phase}`);
  assert.equal(moonPhaseName(i.phase), 'Waxing crescent');
});

test('phase names', () => {
  assert.equal(moonPhaseName(0.005), 'New moon');
  assert.equal(moonPhaseName(0.25), 'First quarter');
  assert.equal(moonPhaseName(0.4), 'Waxing gibbous');
  assert.equal(moonPhaseName(0.5), 'Full moon');
  assert.equal(moonPhaseName(0.6), 'Waning gibbous');
  assert.equal(moonPhaseName(0.9), 'Waning crescent');
});
