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

function sampleData(note) {
  return {
    now: new Date(SAMPLE.now),
    extremes: parsePredictions(SAMPLE.predictions),
    weather: parseForecast(SAMPLE.forecast),
    source: 'sample', note,
  };
}

async function liveData() {
  const now = new Date();
  const [extremes, weather] = await Promise.all([
    fetchExtremes(new Date(+now - DAY), new Date(+now + 2 * DAY)),
    fetchForecast(STATION.lat, STATION.lng),
  ]);
  return { now, extremes, weather, source: 'live' };
}

async function load() {
  if (new URLSearchParams(location.search).has('sample')) return sampleData('Sample requested');
  try { return await liveData(); }
  catch (err) { console.warn('Live data unavailable, using sample:', err); return sampleData(err.message); }
}

function renderHeader(m) {
  $('#date').textContent = fmtLongDate(m.now);
  const status = $('#status');
  if (m.source === 'live') {
    status.className = 'status status-live';
    status.textContent = `Live · updated ${fmtTime(m.now)}`;
  } else {
    status.className = 'status status-sample';
    status.textContent = `Sample data · shown as of ${fmtTime(m.now)}`;
    status.title = m.note || '';
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

async function main() {
  const data = await load();
  const model = buildModel(data);
  renderHeader(model);
  renderNow(model);
  renderChart(model);
  renderHourly(model);
  renderTable(model);
  renderWidgets($('#widgets'), model);

  let raf;
  new ResizeObserver(() => { cancelAnimationFrame(raf); raf = requestAnimationFrame(() => renderChart(model)); }).observe($('#chart'));

  if (model.source === 'live') setTimeout(() => location.reload(), 15 * MIN);
}

main().catch(err => {
  console.error(err);
  $('#status').className = 'status status-sample';
  $('#status').textContent = `Could not render: ${err.message}`;
});
