// Sun and moon rise/set, position and phase. A port of the SunCalc
// algorithms (Vladimir Agafonkin, BSD-2), themselves after Meeus and
// astronomy.stackexchange. Good to a minute or two, which is what a tide
// widget needs.

import { startOfDay, HOUR } from './time.js';

const rad = Math.PI / 180;
const dayMs = 864e5, J1970 = 2440588, J2000 = 2451545;
const toJulian = d => d.valueOf() / dayMs - 0.5 + J1970;
const fromJulian = j => new Date((j + 0.5 - J1970) * dayMs);
const toDays = d => toJulian(d) - J2000;

const e = rad * 23.4397; // obliquity of the Earth
const rightAscension = (l, b) => Math.atan2(Math.sin(l) * Math.cos(e) - Math.tan(b) * Math.sin(e), Math.cos(l));
const declination = (l, b) => Math.asin(Math.sin(b) * Math.cos(e) + Math.cos(b) * Math.sin(e) * Math.sin(l));
const azimuth = (H, phi, dec) => Math.atan2(Math.sin(H), Math.cos(H) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi));
const altitude = (H, phi, dec) => Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H));
const siderealTime = (d, lw) => rad * (280.16 + 360.9856235 * d) - lw;

function astroRefraction(h) {
  if (h < 0) h = 0;
  return 0.0002967 / Math.tan(h + 0.00312536 / (h + 0.08901179));
}

const solarMeanAnomaly = d => rad * (357.5291 + 0.98560028 * d);
function eclipticLongitude(M) {
  const C = rad * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M));
  const P = rad * 102.9372; // perihelion of the Earth
  return M + C + P + Math.PI;
}
function sunCoords(d) {
  const M = solarMeanAnomaly(d), L = eclipticLongitude(M);
  return { dec: declination(L, 0), ra: rightAscension(L, 0) };
}

export function sunPosition(date, lat, lng) {
  const lw = rad * -lng, phi = rad * lat, d = toDays(date);
  const c = sunCoords(d), H = siderealTime(d, lw) - c.ra;
  return { azimuth: azimuth(H, phi, c.dec), altitude: altitude(H, phi, c.dec) };
}

const J0 = 0.0009;
const julianCycle = (d, lw) => Math.round(d - J0 - lw / (2 * Math.PI));
const approxTransit = (Ht, lw, n) => J0 + (Ht + lw) / (2 * Math.PI) + n;
const solarTransitJ = (ds, M, L) => J2000 + ds + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2 * L);
const hourAngle = (h, phi, d) => Math.acos((Math.sin(h) - Math.sin(phi) * Math.sin(d)) / (Math.cos(phi) * Math.cos(d)));
function getSetJ(h, lw, phi, dec, n, M, L) {
  const w = hourAngle(h, phi, dec), a = approxTransit(w, lw, n);
  return solarTransitJ(a, M, L);
}

/** Sun events for the station-zone day containing `date`. */
export function sunTimes(date, lat, lng) {
  const noon = new Date(startOfDay(date).getTime() + 12 * HOUR);
  const lw = rad * -lng, phi = rad * lat, d = toDays(noon);
  const n = julianCycle(d, lw), ds = approxTransit(0, lw, n);
  const M = solarMeanAnomaly(ds), L = eclipticLongitude(M), dec = declination(L, 0);
  const Jnoon = solarTransitJ(ds, M, L);
  const pair = angle => {
    const Jset = getSetJ(angle * rad, lw, phi, dec, n, M, L);
    return [fromJulian(Jnoon - (Jset - Jnoon)), fromJulian(Jset)];
  };
  const [sunrise, sunset] = pair(-0.833);
  const [dawn, dusk] = pair(-6);
  return { sunrise, sunset, dawn, dusk, solarNoon: fromJulian(Jnoon) };
}

function moonCoords(d) {
  const L = rad * (218.316 + 13.176396 * d); // ecliptic longitude
  const M = rad * (134.963 + 13.064993 * d); // mean anomaly
  const F = rad * (93.272 + 13.229350 * d);  // mean distance
  const l = L + rad * 6.289 * Math.sin(M);
  const b = rad * 5.128 * Math.sin(F);
  const dt = 385001 - 20905 * Math.cos(M);   // km
  return { ra: rightAscension(l, b), dec: declination(l, b), dist: dt };
}

export function moonPosition(date, lat, lng) {
  const lw = rad * -lng, phi = rad * lat, d = toDays(date);
  const c = moonCoords(d), H = siderealTime(d, lw) - c.ra;
  let h = altitude(H, phi, c.dec);
  const pa = Math.atan2(Math.sin(H), Math.tan(phi) * Math.cos(c.dec) - Math.sin(c.dec) * Math.cos(H));
  h += astroRefraction(h);
  return { azimuth: azimuth(H, phi, c.dec), altitude: h, distance: c.dist, parallacticAngle: pa };
}

/** fraction lit (0..1), phase (0 new, 0.25 first quarter, 0.5 full, 0.75 last). */
export function moonIllumination(date) {
  const d = toDays(date), s = sunCoords(d), m = moonCoords(d), sdist = 149598000;
  const phi = Math.acos(Math.sin(s.dec) * Math.sin(m.dec) + Math.cos(s.dec) * Math.cos(m.dec) * Math.cos(s.ra - m.ra));
  const inc = Math.atan2(sdist * Math.sin(phi), m.dist - sdist * Math.cos(phi));
  const angle = Math.atan2(Math.cos(s.dec) * Math.sin(s.ra - m.ra),
    Math.sin(s.dec) * Math.cos(m.dec) - Math.cos(s.dec) * Math.sin(m.dec) * Math.cos(s.ra - m.ra));
  return { fraction: (1 + Math.cos(inc)) / 2, phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / Math.PI, angle };
}

const hoursLater = (date, h) => new Date(date.valueOf() + h * dayMs / 24);

/** Moon rise and set within the station-zone day containing `date`. Either
 *  may be absent (the moon rises roughly 50 minutes later each day). */
export function moonTimes(date, lat, lng) {
  const t = startOfDay(date), hc = 0.133 * rad;
  let h0 = moonPosition(t, lat, lng).altitude - hc;
  let rise, set, ye;
  for (let i = 1; i <= 24; i += 2) {
    const h1 = moonPosition(hoursLater(t, i), lat, lng).altitude - hc;
    const h2 = moonPosition(hoursLater(t, i + 1), lat, lng).altitude - hc;
    const a = (h0 + h2) / 2 - h1, b = (h2 - h0) / 2, xe = -b / (2 * a);
    ye = (a * xe + b) * xe + h1;
    const d = b * b - 4 * a * h1;
    let roots = 0, x1 = 0, x2 = 0;
    if (d >= 0) {
      const dx = Math.sqrt(d) / (Math.abs(a) * 2);
      x1 = xe - dx; x2 = xe + dx;
      if (Math.abs(x1) <= 1) roots++;
      if (Math.abs(x2) <= 1) roots++;
      if (x1 < -1) x1 = x2;
    }
    if (roots === 1) { if (h0 < 0) rise = i + x1; else set = i + x1; }
    else if (roots === 2) { rise = i + (ye < 0 ? x2 : x1); set = i + (ye < 0 ? x1 : x2); }
    if (rise !== undefined && set !== undefined) break;
    h0 = h2;
  }
  const r = {};
  if (rise !== undefined) r.rise = hoursLater(t, rise);
  if (set !== undefined) r.set = hoursLater(t, set);
  if (rise === undefined && set === undefined) r[ye > 0 ? 'alwaysUp' : 'alwaysDown'] = true;
  return r;
}

const PHASE_NAMES = ['New moon', 'Waxing crescent', 'First quarter', 'Waxing gibbous',
  'Full moon', 'Waning gibbous', 'Last quarter', 'Waning crescent'];

/** Principal phases only within about half a day of exact. */
export function moonPhaseName(phase) {
  const q = phase * 8, nearest = Math.round(q) % 8;
  if (nearest % 2 === 0 && Math.abs(q - Math.round(q)) < 0.14) return PHASE_NAMES[nearest];
  return PHASE_NAMES[(Math.floor(q) % 8) | 1];
}
