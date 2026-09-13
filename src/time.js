// Time helpers pinned to the station's zone. Marshall is always on Pacific
// time, whatever zone the viewer's device is in.

export const TZ = 'America/Los_Angeles';
export const MIN = 60e3;
export const HOUR = 60 * MIN;
export const DAY = 24 * HOUR;

const partsFmt = new Intl.DateTimeFormat('en-US', {
  timeZone: TZ, hourCycle: 'h23',
  year: 'numeric', month: 'numeric', day: 'numeric',
  hour: 'numeric', minute: 'numeric', second: 'numeric',
});

/** Wall-clock parts of an instant, in the station's zone. */
export function localParts(d) {
  const o = {};
  for (const p of partsFmt.formatToParts(d)) o[p.type] = p.value;
  return {
    year: +o.year, month: +o.month, day: +o.day,
    hour: +o.hour % 24, minute: +o.minute, second: +o.second,
  };
}

/** Offset of the station zone from UTC at a given instant, in ms. */
export function tzOffsetMs(d) {
  const p = localParts(d);
  const wall = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return wall - Math.floor(d.getTime() / 1000) * 1000;
}

/** Instant for a wall-clock time in the station's zone. */
export function fromWall(year, month, day, hour = 0, minute = 0) {
  const wall = Date.UTC(year, month - 1, day, hour, minute);
  let t = wall - tzOffsetMs(new Date(wall));
  t = wall - tzOffsetMs(new Date(t)); // second pass settles DST edges
  return new Date(t);
}

/** Parse "2026-09-13T15:00" or "2026-09-13" as station wall time. */
export function parseWall(iso) {
  const [date, time = '00:00'] = iso.split('T');
  const [y, m, d] = date.split('-').map(Number);
  const [h, mi] = time.split(':').map(Number);
  return fromWall(y, m, d, h, mi);
}

/** Midnight (station zone) of the day containing d. */
export function startOfDay(d) {
  const p = localParts(d);
  return fromWall(p.year, p.month, p.day);
}

export function addDays(d, n) {
  return startOfDay(new Date(startOfDay(d).getTime() + n * DAY + 12 * HOUR));
}

export function sameDay(a, b) {
  const pa = localParts(a), pb = localParts(b);
  return pa.year === pb.year && pa.month === pb.month && pa.day === pb.day;
}

const timeFmt = new Intl.DateTimeFormat('en-US', { timeZone: TZ, hour: 'numeric', minute: '2-digit' });
const dayFmt = new Intl.DateTimeFormat('en-US', { timeZone: TZ, weekday: 'short', month: 'short', day: 'numeric' });
const weekdayFmt = new Intl.DateTimeFormat('en-US', { timeZone: TZ, weekday: 'short' });
const longFmt = new Intl.DateTimeFormat('en-US', { timeZone: TZ, weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });

/** "1:14 PM" */
export const fmtTime = d => timeFmt.format(d);
/** "1:14p" */
export function fmtTimeShort(d) {
  const p = localParts(d);
  return `${p.hour % 12 || 12}:${String(p.minute).padStart(2, '0')}${p.hour < 12 ? 'a' : 'p'}`;
}
/** "1 PM" */
export function fmtHour(d) {
  const p = localParts(d);
  return `${p.hour % 12 || 12} ${p.hour < 12 ? 'AM' : 'PM'}`;
}
/** "1p", "12a" */
export function fmtHourShort(d) {
  const p = localParts(d);
  return `${p.hour % 12 || 12}${p.hour < 12 ? 'a' : 'p'}`;
}
/** "Sun, Sep 13" */
export const fmtDay = d => dayFmt.format(d);
/** "Sun" */
export const fmtWeekday = d => weekdayFmt.format(d);
/** "Sunday, September 13, 2026" */
export const fmtLongDate = d => longFmt.format(d);

/** "1h 40m" or "25m" */
export function fmtDuration(ms) {
  const m = Math.round(Math.abs(ms) / MIN);
  const h = Math.floor(m / 60), mm = m % 60;
  return h ? `${h}h ${String(mm).padStart(2, '0')}m` : `${mm}m`;
}

/** "20260913" in UTC, for the NOAA API when asking for GMT times. */
export function yyyymmddUTC(d) {
  return d.toISOString().slice(0, 10).replace(/-/g, '');
}
