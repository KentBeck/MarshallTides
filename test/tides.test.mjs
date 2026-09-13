import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parsePredictions, heightAt, tideNow, curve, predictionsUrl } from '../src/tides.js';
import { SAMPLE } from '../src/sample-data.js';
import { fromWall, parseWall, startOfDay, fmtTime, fmtDay, tzOffsetMs, HOUR } from '../src/time.js';
import { parseForecast, compass, describeCode } from '../src/weather.js';

const ex = parsePredictions(SAMPLE.predictions);

test('extremes parse as UTC instants, sorted', () => {
  assert.equal(ex[0].time.toISOString(), '2026-09-12T07:10:00.000Z');
  assert.equal(ex[0].type, 'H');
  for (let i = 1; i < ex.length; i++) assert.ok(ex[i].time > ex[i - 1].time);
});

test('interpolation hits the extremes and the midpoint', () => {
  const a = ex[4], b = ex[5]; // 5.4 H -> 1.9 L
  assert.equal(heightAt(ex, a.time), 5.4);
  assert.ok(Math.abs(heightAt(ex, b.time) - 1.9) < 1e-9);
  const mid = new Date((+a.time + +b.time) / 2);
  assert.ok(Math.abs(heightAt(ex, mid) - 3.65) < 1e-9);
});

test('tideNow reports direction and next extreme', () => {
  const now = new Date(SAMPLE.now);
  const t = tideNow(ex, now);
  assert.equal(t.rising, true);
  assert.equal(t.next.height, 6.3);
  assert.equal(t.prev.height, 1.9);
  assert.ok(t.height > 1.9 && t.height < 6.3);
});

test('curve spans the window inclusively', () => {
  const start = new Date(SAMPLE.now), end = new Date(+start + 24 * HOUR);
  const c = curve(ex, start, end);
  assert.equal(+c[0].time, +start);
  assert.equal(+c[c.length - 1].time, +end);
});

test('NOAA url asks for GMT hi/lo predictions', () => {
  const u = predictionsUrl(new Date('2026-09-12T18:00Z'), new Date('2026-09-15T18:00Z'));
  assert.match(u, /station=9415625/);
  assert.match(u, /begin_date=20260912/);
  assert.match(u, /end_date=20260915/);
  assert.match(u, /time_zone=gmt/);
  assert.match(u, /interval=hilo/);
});

test('station wall time helpers', () => {
  assert.equal(tzOffsetMs(new Date('2026-09-13T18:30Z')), -7 * HOUR); // PDT
  assert.equal(tzOffsetMs(new Date('2026-01-13T18:30Z')), -8 * HOUR); // PST
  assert.equal(fromWall(2026, 9, 13, 11, 30).toISOString(), '2026-09-13T18:30:00.000Z');
  assert.equal(parseWall('2026-09-13T11:30').toISOString(), '2026-09-13T18:30:00.000Z');
  assert.equal(startOfDay(new Date('2026-09-13T18:30Z')).toISOString(), '2026-09-13T07:00:00.000Z');
  assert.equal(fmtTime(new Date('2026-09-13T18:30Z')), '11:30 AM');
  assert.equal(fmtDay(new Date('2026-09-13T18:30Z')), 'Sun, Sep 13');
});

test('forecast parses into station-zone instants', () => {
  const f = parseForecast(SAMPLE.forecast);
  assert.equal(f.current.time.toISOString(), '2026-09-13T18:30:00.000Z');
  assert.equal(f.hourly.length, 72);
  assert.equal(f.hourly[0].time.toISOString(), '2026-09-13T07:00:00.000Z');
  assert.equal(f.daily[0].hi, 66.2);
  assert.equal(compass(312), 'NW');
  assert.equal(compass(0), 'N');
  assert.equal(compass(359), 'N');
  assert.deepEqual(describeCode(45), { label: 'Fog', icon: 'fog' });
  assert.deepEqual(describeCode(0, false), { label: 'Clear', icon: 'moon' });
});
