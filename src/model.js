// Turns raw tide, weather and astronomy into what the page and widgets show.

import { sunTimes, moonTimes, moonIllumination, moonPhaseName } from './astro.js';
import { curve, tideNow, STATION } from './tides.js';
import { startOfDay, addDays, HOUR, MIN } from './time.js';

/** Sun and moon events for the local days from `from` to `to` (inclusive). */
function skyEvents(from, to, lat, lng) {
  const sun = [], moon = [];
  for (let d = startOfDay(from); d <= to; d = addDays(d, 1)) {
    const s = sunTimes(d, lat, lng);
    sun.push({ time: s.sunrise, kind: 'sunrise' }, { time: s.sunset, kind: 'sunset' });
    const m = moonTimes(d, lat, lng);
    if (m.rise) moon.push({ time: m.rise, kind: 'moonrise' });
    if (m.set) moon.push({ time: m.set, kind: 'moonset' });
  }
  moon.sort((a, b) => a.time - b.time);
  return { sun, moon };
}

/** [sunset, next sunrise] pairs clipped to [start, end]. */
function nightBands(sun, start, end) {
  const bands = [];
  let dusk = start; // assume night until proven otherwise
  for (const ev of sun) {
    if (ev.kind === 'sunset') dusk = ev.time;
    else if (ev.kind === 'sunrise') {
      if (ev.time > start) bands.push({ from: new Date(Math.max(+dusk, +start)), to: new Date(Math.min(+ev.time, +end)) });
      dusk = null;
    }
  }
  if (dusk && dusk < end) bands.push({ from: new Date(Math.max(+dusk, +start)), to: end });
  return bands.filter(b => b.to > b.from);
}

/** A chart window around `now`. */
export function windowFor(model, pastHours, futureHours) {
  const start = new Date(+model.now - pastHours * HOUR);
  const end = new Date(+model.now + futureHours * HOUR);
  const inWin = e => e.time >= start && e.time <= end;
  return {
    start, end, now: model.now,
    curve: curve(model.extremes, start, end, 6 * MIN),
    extremes: model.extremes.filter(inWin),
    sun: model.sky.sun.filter(inWin),
    moon: model.sky.moon.filter(inWin),
    nights: nightBands(model.sky.sun, start, end),
  };
}

export function buildModel({ now, extremes, weather, source = 'live', sources = {} }) {
  const { lat, lng } = STATION;
  const sky = skyEvents(addDays(now, -1), addDays(now, 2), lat, lng);
  const today = sunTimes(now, lat, lng);
  const moonToday = moonTimes(now, lat, lng);
  const illum = moonIllumination(now);
  const tide = tideNow(extremes, now);

  // Next sun event after now, for the "what's next" readout.
  const nextSun = sky.sun.find(e => e.time > now);
  const nextMoon = sky.moon.find(e => e.time > now);

  const hourly = weather.hourly.filter(h => h.time >= +now - 30 * MIN).slice(0, 24);
  const current = weather.current;

  return {
    now, source, sources, station: STATION,
    extremes, sky, tide,
    sun: { ...today, next: nextSun, daylight: today.sunset - today.sunrise },
    moon: {
      ...moonToday, next: nextMoon,
      fraction: illum.fraction, phase: illum.phase, name: moonPhaseName(illum.phase),
    },
    weather: { current, hourly, daily: weather.daily },
  };
}
