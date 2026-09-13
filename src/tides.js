// NOAA CO-OPS tide predictions for Marshall, Tomales Bay. Marshall is a
// subordinate station, so NOAA publishes only the highs and lows; the curve
// between them is a cosine, the same approximation the printed tide tables
// assume.

import { MIN, yyyymmddUTC } from './time.js';

export const STATION = {
  id: '9415625',
  name: 'Marshall, Tomales Bay',
  lat: 38.1616,
  lng: -122.8886,
  datum: 'MLLW',
  units: 'ft',
};

const API = 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter';

export function predictionsUrl(begin, end, station = STATION.id) {
  const q = new URLSearchParams({
    product: 'predictions', application: 'MarshallTides',
    begin_date: yyyymmddUTC(begin), end_date: yyyymmddUTC(end),
    datum: STATION.datum, station, time_zone: 'gmt', units: 'english',
    interval: 'hilo', format: 'json',
  });
  return `${API}?${q}`;
}

/** NOAA JSON -> [{time, height, type: 'H'|'L'}] sorted by time. */
export function parsePredictions(json) {
  if (json.error) throw new Error(`NOAA: ${json.error.message}`);
  return json.predictions
    .map(p => ({ time: new Date(p.t.replace(' ', 'T') + 'Z'), height: +p.v, type: p.type }))
    .sort((a, b) => a.time - b.time);
}

export async function fetchExtremes(begin, end, fetchImpl = fetch) {
  const res = await fetchImpl(predictionsUrl(begin, end));
  if (!res.ok) throw new Error(`NOAA ${res.status}`);
  return parsePredictions(await res.json());
}

/** Height at instant t, cosine-interpolated between neighbouring extremes. */
export function heightAt(extremes, t) {
  const ms = +t;
  if (ms <= +extremes[0].time) return extremes[0].height;
  for (let i = 1; i < extremes.length; i++) {
    const a = extremes[i - 1], b = extremes[i];
    if (ms <= +b.time) {
      const f = (ms - a.time) / (b.time - a.time);
      return (a.height + b.height) / 2 + (a.height - b.height) / 2 * Math.cos(Math.PI * f);
    }
  }
  return extremes[extremes.length - 1].height;
}

/** Sampled curve from start to end inclusive. */
export function curve(extremes, start, end, stepMs = 10 * MIN) {
  const pts = [];
  for (let t = +start; t < +end; t += stepMs) pts.push({ time: new Date(t), height: heightAt(extremes, t) });
  pts.push({ time: new Date(end), height: heightAt(extremes, end) });
  return pts;
}

/** Where the tide is right now and what comes next. */
export function tideNow(extremes, now) {
  const i = extremes.findIndex(e => e.time > now);
  const next = i >= 0 ? extremes[i] : null;
  const prev = i > 0 ? extremes[i - 1] : null;
  return {
    height: heightAt(extremes, now),
    rising: next ? next.type === 'H' : false,
    next, prev,
    upcoming: i >= 0 ? extremes.slice(i) : [],
  };
}
