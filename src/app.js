import { STATION, fetchExtremes, parsePredictions } from './tides.js';
import { fetchForecast, parseForecast, describeCode, compass } from './weather.js';
import { buildModel, windowFor } from './model.js';
import { renderTideChart } from './chart.js';
import { renderWidgets, moonSvg } from './widgets.js';
import { SAMPLE } from './sample-data.js';
import { fmtTime, fmtTimeShort, fmtLongDate, fmtDuration, fmtHourShort, fmtWeekday, DAY, MIN } from './time.js';

const $ = sel => document.querySelector(sel);
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const ft = h => (Math.round(h * 10) / 10).toFixed(1);
const deg = t => `${Math.round(t)}°`;
const icon = (id, cls = '') => `<svg class="ic ${cls}" aria-hidden="true"><use href="#i-${id}"/></svg>`;

/** The sample is pinned to a September day; shift it by whole days so it
 *  sits on today's date and the real clock can drive the display. */
function sampleData(now) {
  const days = Math.round((now - new Date(SAMPLE.now)) / DAY);
  const shift = d => new Date(+d + days * DAY);
  const weather = parseForecast(SAMPLE.forecast);
  return {
    extremes: parsePredictions(SAMPLE.predictions).map(e => ({ ...e, time: shift(e.time) })),
    weather: {
      current: { ...weather.current, time: now },
      hourly: weather.hourly.map(h => ({ ...h, time: shift(h.time) })),
      daily: weather.daily.map(d => ({ ...d, time: shift(d.time) })),
    },
  };
}

/** Tides and weather are fetched independently, so one can be live while
 *  the other falls back to the sample. `sources` records which is which. */
async function load() {
  const now = new Date();
  const sample = sampleData(now);
  const forced = new URLSearchParams(location.search).has('sample');
  const attempt = forced
    ? () => Promise.reject(new Error('sample requested'))
    : null;
  const [tides, weather] = await Promise.allSettled([
    attempt ? attempt() : fetchExtremes(new Date(+now - DAY), new Date(+now + 2 * DAY)),
    attempt ? attempt() : fetchForecast(STATION.lat, STATION.lng),
  ]);
  const report = (r, name) => r.status === 'fulfilled'
    ? { live: true }
    : { live: false, error: `${name}: ${r.reason?.message || r.reason}` };
  const sources = { tides: report(tides, 'NOAA'), weather: report(weather, 'Open-Meteo') };
  for (const k of Object.keys(sources)) if (!sources[k].live) console.warn(sources[k].error);
  const liveCount = Object.values(sources).filter(s => s.live).length;
  return {
    now,
    extremes: tides.status === 'fulfilled' ? tides.value : sample.extremes,
    weather: weather.status === 'fulfilled' ? weather.value : sample.weather,
    sources,
    source: liveCount === 2 ? 'live' : liveCount === 1 ? 'partial' : 'sample',
  };
}

function renderHeader(m, dataAt) {
  $('#date').textContent = fmtLongDate(m.now);
  const status = $('#status');
  const { tides, weather } = m.sources;
  const errors = [tides, weather].filter(s => !s.live).map(s => s.error).join(' · ');
  const blocked = !tides.live && !weather.live && /Failed to fetch|Load failed|NetworkError/.test(errors);
  if (m.source === 'live') {
    status.className = 'status status-live';
    status.textContent = `Live · data ${fmtTime(dataAt)} · shown ${fmtTime(m.now)}`;
    status.title = 'Data refreshes every hour, the display every minute';
  } else if (m.source === 'partial') {
    status.className = 'status status-sample';
    status.textContent = `${tides.live ? 'Tides live, weather sample' : 'Weather live, tides sample'} · ${errors}`;
  } else {
    status.className = 'status status-sample';
    status.textContent = blocked
      ? 'Sample data · this page can\'t reach the internet from here, so NOAA and Open-Meteo are unreachable. Serve it from your own machine or GitHub Pages for live data.'
      : `Sample data · ${errors}`;
  }
}

function renderNow(m) {
  const t = m.tide, s = m.sun, mo = m.moon, w = m.weather.current;
  const cond = describeCode(w.code, w.isDay);
  const untilNext = t.next ? fmtDuration(t.next.time - m.now) : '';
  const after = t.upcoming[1];
  $('#tide').innerHTML = `
    <div class="r-big">${ft(t.height)}<span class="r-unit">ft</span><span class="r-trend">${icon(t.rising ? 'up' : 'down')}${t.rising ? 'rising' : 'falling'}</span></div>
    <div class="r-line">${t.next ? `<b>${t.next.type === 'H' ? 'High' : 'Low'} ${ft(t.next.height)} ft</b> at ${esc(fmtTime(t.next.time))} <span class="r-dim">in ${untilNext}</span>` : ''}</div>
    <div class="r-line r-dim">${after ? `then ${after.type === 'H' ? 'high' : 'low'} ${ft(after.height)} ft at ${esc(fmtTime(after.time))}` : ''}</div>`;

  const isDay = m.now > s.sunrise && m.now < s.sunset;
  $('#sun').innerHTML = `
    <div class="r-big r-big-time">${icon(isDay ? 'sunset' : 'sunrise', 'ic-sun')}${esc(fmtTime(isDay ? s.sunset : s.next?.time || s.sunrise))}</div>
    <div class="r-line"><b>${isDay ? 'Sunset' : 'Sunrise'}</b> <span class="r-dim">in ${fmtDuration((isDay ? s.sunset : s.next?.time || s.sunrise) - m.now)}</span></div>
    <div class="r-line r-dim">Rise ${esc(fmtTime(s.sunrise))} · Set ${esc(fmtTime(s.sunset))} · ${fmtDuration(s.daylight)} of daylight</div>`;

  $('#moon').innerHTML = `
    <div class="r-big r-big-time">${moonSvg(mo.phase, 30, 'moon-lg')}${Math.round(mo.fraction * 100)}<span class="r-unit">%</span></div>
    <div class="r-line"><b>${esc(mo.name)}</b></div>
    <div class="r-line r-dim">Rise ${mo.rise ? esc(fmtTime(mo.rise)) : '—'} · Set ${mo.set ? esc(fmtTime(mo.set)) : '—'}</div>`;

  const today = m.weather.daily[0];
  $('#weather').innerHTML = `
    <div class="r-big r-big-time">${icon(cond.icon, 'ic-wx')}${deg(w.temp)}</div>
    <div class="r-line"><b>${esc(cond.label)}</b> · wind ${esc(compass(w.dir))} ${Math.round(w.wind)} mph, gusts ${Math.round(w.gust)}</div>
    <div class="r-line r-dim">${today ? `High ${deg(today.hi)} · Low ${deg(today.lo)}` : ''} · feels like ${deg(w.feels)}</div>`;
}

function renderHourly(m) {
  const rows = m.weather.hourly;
  const temps = rows.map(h => h.temp), lo = Math.min(...temps), hi = Math.max(...temps);
  $('#hourly').innerHTML = rows.map(h => {
    const c = describeCode(h.code, h.isDay);
    const level = (h.temp - lo) / (hi - lo || 1);
    return `<div class="hr" title="${esc(c.label)}">
      <span class="hr-t">${esc(fmtHourShort(h.time))}</span>
      ${icon(c.icon, 'hr-ic')}
      <span class="hr-temp" style="--lvl:${level.toFixed(2)}"><i></i>${deg(h.temp)}</span>
      <span class="hr-wind"><i class="arrow" style="--rot:${(h.dir + 180) % 360}deg">${icon('wind-arrow')}</i>${Math.round(h.wind)}</span>
    </div>`;
  }).join('');
  $('#daily').innerHTML = m.weather.daily.map((d, i) => {
    const c = describeCode(d.code, true);
    return `<div class="day"><span class="day-n">${i === 0 ? 'Today' : esc(fmtWeekday(d.time))}</span>${icon(c.icon)}<span class="day-c">${esc(c.label)}</span><span class="day-t">${deg(d.hi)} <span class="r-dim">/ ${deg(d.lo)}</span></span><span class="day-w">wind to ${Math.round(d.windMax)} mph</span></div>`;
  }).join('');
}

function renderTable(m) {
  const rows = m.extremes.filter(e => e.time > +m.now - 6 * 3600e3 && e.time < +m.now + 30 * 3600e3);
  $('#tidetable').innerHTML = rows.map(e => `<tr class="${e.time < m.now ? 'past' : ''}"><td>${esc(fmtWeekday(e.time))}</td><td>${esc(fmtTime(e.time))}</td><td>${e.type === 'H' ? 'High' : 'Low'}</td><td class="num">${ft(e.height)} ft</td></tr>`).join('');
}

function renderChart(m) {
  const el = $('#chart');
  const win = windowFor(m, 6, 30);
  renderTideChart(el, win, { width: Math.max(320, el.clientWidth), height: el.clientWidth < 560 ? 260 : 320, extremes: m.extremes });
}

const DISPLAY_EVERY = MIN;
const DATA_EVERY = 60 * MIN;

let data = null;       // extremes + forecast, refetched hourly
let dataAt = null;     // wall-clock time of that fetch
let model = null;

async function refreshData() {
  data = await load();
  dataAt = new Date();
}

function renderAll() {
  model = buildModel({ ...data, now: new Date() });
  renderHeader(model, dataAt);
  renderNow(model);
  renderChart(model);
  renderHourly(model);
  renderTable(model);
  renderWidgets($('#widgets'), model);
}

/** Fire on the minute so the display keeps step with the clock. */
function everyMinute(fn) {
  const tick = () => { fn(); setTimeout(tick, DISPLAY_EVERY - (Date.now() % DISPLAY_EVERY)); };
  setTimeout(tick, DISPLAY_EVERY - (Date.now() % DISPLAY_EVERY));
}

async function main() {
  await refreshData();
  renderAll();

  let raf;
  new ResizeObserver(() => { cancelAnimationFrame(raf); raf = requestAnimationFrame(() => model && renderChart(model)); }).observe($('#chart'));

  everyMinute(renderAll);
  setInterval(async () => { await refreshData(); renderAll(); }, DATA_EVERY);

  // Coming back to a background tab: catch the display up, and the data if it went stale.
  document.addEventListener('visibilitychange', async () => {
    if (document.hidden) return;
    if (Date.now() - dataAt > DATA_EVERY) await refreshData();
    renderAll();
  });
}

main().catch(err => {
  console.error(err);
  $('#status').className = 'status status-sample';
  $('#status').textContent = `Could not render: ${err.message}`;
});
