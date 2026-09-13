// Widget mockups at true point sizes, rendered from the same model as the
// page. iPhone home screen (small, medium, large), lock screen, and Apple
// Watch complications. System font on purpose: this is how SF will set it.

import { renderTideChart } from './chart.js';
import { windowFor } from './model.js';
import { fmtTime, fmtTimeShort, fmtDuration, fmtHourShort } from './time.js';
import { compass, describeCode } from './weather.js';

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const ft = h => (Math.round(h * 10) / 10).toFixed(1);
const deg = t => `${Math.round(t)}°`;
const icon = (id, cls = '') => `<svg class="ic ${cls}" aria-hidden="true"><use href="#i-${id}"/></svg>`;

export function moonSvg(phase, size = 24, cls = '') {
  const r = size / 2 - 1, cx = size / 2, cy = size / 2;
  const k = Math.cos(2 * Math.PI * phase), rx = Math.max(0.01, Math.abs(k) * r);
  const waxing = phase < 0.5;
  // lit limb on the right while waxing, left while waning; the terminator
  // bulges toward the lit side before the quarter and away after it.
  const limbSweep = waxing ? 1 : 0;
  const bulgeToLit = phase < 0.25 || phase > 0.75;
  const termSweep = waxing ? (bulgeToLit ? 0 : 1) : (bulgeToLit ? 1 : 0);
  const d = `M${cx} ${cy - r}A${r} ${r} 0 0 ${limbSweep} ${cx} ${cy + r}A${rx} ${r} 0 0 ${termSweep} ${cx} ${cy - r}Z`;
  return `<svg class="moon ${cls}" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-hidden="true"><circle class="moon-dark" cx="${cx}" cy="${cy}" r="${r}"/><path class="moon-lit" d="${d}"/></svg>`;
}

function trendWord(tide) { return tide.rising ? 'rising' : 'falling'; }
function nextLine(tide) {
  if (!tide.next) return '';
  return `${tide.next.type === 'H' ? 'High' : 'Low'} ${ft(tide.next.height)} ft at ${fmtTime(tide.next.time)}`;
}
function windLine(w) { return `${compass(w.dir)} ${Math.round(w.wind)} mph`; }
function windShort(w) { return `${compass(w.dir)} ${Math.round(w.wind)}`; }
function nextShort(tide) {
  if (!tide.next) return '';
  return `${tide.next.type === 'H' ? 'High' : 'Low'} ${ft(tide.next.height)} · ${fmtTimeShort(tide.next.time)}`;
}

export function renderWidgets(root, model) {
  const t = model.tide, w = model.weather.current, s = model.sun, mo = model.moon;
  const cond = describeCode(w.code, w.isDay);
  const up = icon(t.rising ? 'up' : 'down', 'ic-trend');

  root.innerHTML = `
  <div class="wgroup">
    <h3 class="wgroup-t">iPhone home screen</h3>
    <div class="wrow">
      <figure class="wfig">
        <div class="w w-small">
          <div class="w-head"><span class="w-place">Marshall</span><span class="w-trend">${up}${trendWord(t)}</span></div>
          <div class="w-big">${ft(t.height)}<span class="w-unit">ft</span></div>
          <div class="w-next">${esc(nextLine(t))}</div>
          <div class="w-chart" data-chart="small"></div>
          <div class="w-foot">
            <span>${icon('sunrise')}${esc(fmtTimeShort(s.sunrise))}</span>
            <span>${icon('sunset')}${esc(fmtTimeShort(s.sunset))}</span>
            <span>${deg(w.temp)} ${esc(windShort(w))}</span>
          </div>
        </div>
        <figcaption>Small · 170×170</figcaption>
      </figure>

      <figure class="wfig">
        <div class="w w-medium">
          <div class="w-col">
            <div class="w-head"><span class="w-place">Marshall</span><span class="w-trend">${up}${trendWord(t)}</span></div>
            <div class="w-big">${ft(t.height)}<span class="w-unit">ft</span></div>
            <div class="w-next">${esc(nextLine(t))}</div>
            <div class="w-list">
              <div>${icon('sunrise')}<span>${esc(fmtTimeShort(s.sunrise))}</span>${icon('sunset')}<span>${esc(fmtTimeShort(s.sunset))}</span></div>
              <div>${icon('moonrise')}<span>${mo.rise ? esc(fmtTimeShort(mo.rise)) : '—'}</span>${icon('moonset')}<span>${mo.set ? esc(fmtTimeShort(mo.set)) : '—'}</span></div>
              <div>${icon(cond.icon)}<span>${deg(w.temp)}</span>${icon('wind')}<span>${esc(windShort(w))}</span></div>
            </div>
          </div>
          <div class="w-chart w-chart-side" data-chart="medium"></div>
        </div>
        <figcaption>Medium · 364×170</figcaption>
      </figure>
    </div>

    <div class="wrow">
      <figure class="wfig">
        <div class="w w-large">
          <div class="w-head">
            <span class="w-place">Marshall</span>
            <span class="w-wx">${icon(cond.icon)}${deg(w.temp)} ${esc(cond.label)} · ${esc(windShort(w))}, gusts ${Math.round(w.gust)}</span>
          </div>
          <div class="w-large-top">
            <div class="w-big">${ft(t.height)}<span class="w-unit">ft</span><span class="w-trend">${up}${trendWord(t)}</span></div>
            <div class="w-next-list">${t.upcoming.slice(0, 3).map(e => `<span><b>${e.type === 'H' ? 'High' : 'Low'}</b> ${ft(e.height)} · ${esc(fmtTimeShort(e.time))}</span>`).join('')}</div>
          </div>
          <div class="w-chart" data-chart="large"></div>
          <div class="w-hours">${model.weather.hourly.filter((_, i) => i % 3 === 0).slice(0, 8).map(h => `
            <div class="w-hour"><span class="w-hour-t">${esc(fmtHourShort(h.time))}</span>${icon(describeCode(h.code, h.isDay).icon)}<span class="w-hour-v">${deg(h.temp)}</span><span class="w-hour-w">${icon('wind-arrow', 'ic-arrow')}<i style="--rot:${(h.dir + 180) % 360}deg"></i>${Math.round(h.wind)}</span></div>`).join('')}
          </div>
          <div class="w-list w-list-row">
            <div>${icon('sunrise')}<span>${esc(fmtTimeShort(s.sunrise))}</span>${icon('sunset')}<span>${esc(fmtTimeShort(s.sunset))}</span></div>
            <div>${moonSvg(mo.phase, 14)}<span>${esc(mo.name)}</span></div>
            <div>${icon('moonrise')}<span>${mo.rise ? esc(fmtTimeShort(mo.rise)) : '—'}</span>${icon('moonset')}<span>${mo.set ? esc(fmtTimeShort(mo.set)) : '—'}</span></div>
          </div>
        </div>
        <figcaption>Large · 364×382</figcaption>
      </figure>
    </div>
  </div>

  <div class="wgroup">
    <h3 class="wgroup-t">Lock screen</h3>
    <div class="wrow">
      <figure class="wfig">
        <div class="w w-lock w-inline">${up}${ft(t.height)} ft · ${esc(nextShort(t))}</div>
        <figcaption>Inline (above the clock)</figcaption>
      </figure>
      <figure class="wfig">
        <div class="w w-lock w-rect">
          <div class="w-rect-l"><b>${ft(t.height)} ft</b> ${up}<span class="w-rect-next">${esc(nextShort(t))}</span></div>
          <div class="w-chart" data-chart="rect"></div>
        </div>
        <figcaption>Rectangular · 160×72</figcaption>
      </figure>
      <figure class="wfig">
        <div class="w w-lock w-circ" data-gauge="lock">${gauge(model, 66)}</div>
        <figcaption>Circular · 72×72</figcaption>
      </figure>
    </div>
  </div>

  <div class="wgroup">
    <h3 class="wgroup-t">Apple Watch</h3>
    <div class="wrow">
      <figure class="wfig">
        <div class="w w-watch w-watch-rect">
          <div class="w-rect-l"><b>${ft(t.height)} ft</b> ${up}<span class="w-rect-next">${esc(nextShort(t))}</span></div>
          <div class="w-chart" data-chart="watch"></div>
          <div class="w-rect-foot">${icon('sunrise')}${esc(fmtTimeShort(s.sunrise))} ${icon('sunset')}${esc(fmtTimeShort(s.sunset))} · ${deg(w.temp)} ${esc(windShort(w))}</div>
        </div>
        <figcaption>Rectangular · 184×84</figcaption>
      </figure>
      <figure class="wfig">
        <div class="w w-watch w-watch-circ">${gauge(model, 56)}</div>
        <figcaption>Circular · 56×56</figcaption>
      </figure>
      <figure class="wfig">
        <div class="w w-watch w-watch-corner">
          <span class="w-corner-v">${ft(t.height)}${up}</span>
          <span class="w-corner-l">${esc(t.next ? `${t.next.type === 'H' ? 'H' : 'L'} ${fmtTimeShort(t.next.time)}` : '')}</span>
        </div>
        <figcaption>Corner</figcaption>
      </figure>
    </div>
  </div>`;

  // charts in the mockups
  const wins = {
    small: windowFor(model, 3, 21), medium: windowFor(model, 4, 20), large: windowFor(model, 6, 30),
    rect: windowFor(model, 2, 22), watch: windowFor(model, 2, 22),
  };
  const specs = {
    small: { width: 146, height: 44, compact: true, rail: false, axes: false, labels: false, hover: false },
    medium: { width: 178, height: 146, compact: true, rail: true, axes: true, labels: true, hover: false },
    large: { width: 332, height: 150, compact: true, rail: true, axes: true, labels: true, hover: false },
    rect: { width: 150, height: 36, compact: true, rail: false, axes: false, labels: false, hover: false },
    watch: { width: 170, height: 34, compact: true, rail: false, axes: false, labels: false, hover: false },
  };
  for (const el of root.querySelectorAll('[data-chart]')) {
    const k = el.dataset.chart;
    renderTideChart(el, wins[k], { ...specs[k], extremes: model.extremes });
  }
}

/** Circular complication: a ring showing where the tide sits in the day's range. */
function gauge(model, size) {
  const t = model.tide;
  const day = model.extremes.filter(e => Math.abs(e.time - model.now) < 15 * 3600e3);
  const lo = Math.min(...day.map(e => e.height)), hi = Math.max(...day.map(e => e.height));
  const f = Math.max(0, Math.min(1, (t.height - lo) / (hi - lo || 1)));
  const r = size / 2 - 4, c = 2 * Math.PI * r, cx = size / 2, cy = size / 2;
  return `<svg class="gauge" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-label="Tide ${ft(t.height)} feet, ${trendWord(t)}">
    <circle class="gauge-track" cx="${cx}" cy="${cy}" r="${r}"/>
    <circle class="gauge-fill" cx="${cx}" cy="${cy}" r="${r}" stroke-dasharray="${(c * 0.75 * f).toFixed(1)} ${c.toFixed(1)}" transform="rotate(135 ${cx} ${cy})"/>
    <text class="gauge-v" x="${cx}" y="${cy + 3}" text-anchor="middle">${ft(t.height)}</text>
    <text class="gauge-l" x="${cx}" y="${cy + 13}" text-anchor="middle">${t.rising ? '▲' : '▼'} ${t.next ? esc(fmtTimeShort(t.next.time)) : ''}</text>
  </svg>`;
}
