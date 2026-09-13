// The tide curve. One scale, thin marks, night shading from the sun events,
// a sun/moon rail along the top, and a crosshair on hover.

import { fmtHour, fmtHourShort, fmtTime, fmtTimeShort, fmtWeekday, fmtDay, startOfDay, localParts, HOUR } from './time.js';
import { heightAt } from './tides.js';

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const fmtFt = h => (Math.round(h * 10) / 10).toFixed(1);

/**
 * opts: width, height, compact (widget scale), rail (sun/moon row), axes,
 *       labels (hi/lo labels), hover, extremes (full list for hover lookups)
 */
export function renderTideChart(container, win, opts = {}) {
  const {
    width = container.clientWidth || 600, height = 300, compact = false,
    rail = true, axes = true, labels = true, hover = !compact, extremes = null,
  } = opts;

  const m = compact
    ? { top: rail ? 16 : 6, right: 6, bottom: axes ? 14 : 6, left: axes ? 18 : 6 }
    : { top: rail ? 52 : 16, right: 16, bottom: axes ? 30 : 12, left: axes ? 40 : 12 };
  const pw = width - m.left - m.right, ph = height - m.top - m.bottom;

  const heights = win.curve.map(p => p.height);
  const lo = Math.min(...heights), hi = Math.max(...heights);
  const yMin = Math.floor(lo - (compact ? 0.4 : 0.8));
  const yMax = Math.ceil(hi + (compact ? 0.8 : 1.2));
  const x = t => m.left + (t - win.start) / (win.end - win.start) * pw;
  const y = h => m.top + (yMax - h) / (yMax - yMin) * ph;
  const bottom = m.top + ph;

  const out = [];
  // night
  for (const b of win.nights) {
    out.push(`<rect class="c-night" x="${x(b.from).toFixed(1)}" y="${m.top}" width="${(x(b.to) - x(b.from)).toFixed(1)}" height="${ph}"/>`);
  }
  // grid + y labels
  const step = yMax - yMin > 7 ? 2 : 1;
  for (let v = Math.ceil(yMin / step) * step; v <= yMax; v += step) {
    out.push(`<line class="c-grid" x1="${m.left}" x2="${m.left + pw}" y1="${y(v).toFixed(1)}" y2="${y(v).toFixed(1)}"/>`);
    if (axes) out.push(`<text class="c-axis" x="${m.left - 6}" y="${(y(v) + 3.5).toFixed(1)}" text-anchor="end">${v}${!compact && v === Math.ceil(yMin / step) * step ? ' ft' : ''}</text>`);
  }
  // x ticks every 6h from local midnight, day boundaries emphasised
  const t0 = startOfDay(win.start);
  const pxPer6h = pw / ((win.end - win.start) / HOUR) * 6;
  const tickHours = pxPer6h < (compact ? 34 : 68) ? 12 : 6;
  for (let t = +t0; t <= +win.end; t += tickHours * HOUR) {
    if (t < +win.start) continue;
    const midnight = localParts(new Date(t)).hour === 0;
    const xx = x(t).toFixed(1);
    if (midnight) out.push(`<line class="c-day" x1="${xx}" x2="${xx}" y1="${m.top}" y2="${bottom}"/>`);
    if (axes) {
      out.push(`<line class="c-tick" x1="${xx}" x2="${xx}" y1="${bottom}" y2="${bottom + 4}"/>`);
      const lab = midnight ? (compact ? fmtWeekday(new Date(t)) : fmtDay(new Date(t))) : (compact ? fmtHourShort(new Date(t)) : fmtHour(new Date(t)));
      out.push(`<text class="c-axis${midnight ? ' c-axis-day' : ''}" x="${xx}" y="${bottom + (compact ? 12 : 18)}" text-anchor="middle">${esc(lab)}</text>`);
    }
  }
  // baseline
  out.push(`<line class="c-base" x1="${m.left}" x2="${m.left + pw}" y1="${bottom}" y2="${bottom}"/>`);

  // curve: past (dashed) and future (solid, with area)
  const pts = win.curve.map(p => [x(p.time), y(p.height)]);
  const iNow = win.curve.findIndex(p => p.time >= win.now);
  const seg = (arr) => arr.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join('');
  const past = pts.slice(0, Math.max(iNow + 1, 1)), future = pts.slice(Math.max(iNow, 0));
  const gid = `g${Math.random().toString(36).slice(2, 8)}`;
  out.push(`<defs><linearGradient id="${gid}" x1="0" x2="0" y1="0" y2="1"><stop offset="0" class="c-area-top"/><stop offset="1" class="c-area-bot"/></linearGradient></defs>`);
  if (future.length > 1) out.push(`<path class="c-area" fill="url(#${gid})" d="${seg(future)}L${future[future.length - 1][0].toFixed(1)} ${bottom}L${future[0][0].toFixed(1)} ${bottom}Z"/>`);
  if (past.length > 1) out.push(`<path class="c-line c-past" d="${seg(past)}"/>`);
  if (future.length > 1) out.push(`<path class="c-line" d="${seg(future)}"/>`);

  // high / low labels
  if (labels) {
    for (const e of win.extremes) {
      const xx = x(e.time), yy = y(e.height), high = e.type === 'H';
      const anchor = xx < m.left + 24 ? 'start' : xx > m.left + pw - 24 ? 'end' : 'middle';
      if (compact) {
        out.push(`<text class="c-lab" x="${xx.toFixed(1)}" y="${(high ? yy - 5 : yy + 11).toFixed(1)}" text-anchor="${anchor}">${fmtFt(e.height)}</text>`);
      } else {
        out.push(`<text class="c-lab" x="${xx.toFixed(1)}" y="${(high ? yy - 22 : yy + 18).toFixed(1)}" text-anchor="${anchor}">${fmtFt(e.height)} ft</text>`);
        out.push(`<text class="c-lab-t" x="${xx.toFixed(1)}" y="${(high ? yy - 9 : yy + 31).toFixed(1)}" text-anchor="${anchor}">${esc(fmtTimeShort(e.time))}</text>`);
      }
      out.push(`<circle class="c-ext" cx="${xx.toFixed(1)}" cy="${yy.toFixed(1)}" r="${compact ? 2 : 3}"/>`);
    }
  }

  // now
  const ext = extremes || win.extremes;
  const xn = x(win.now), hn = ext.length ? heightAt(ext, win.now) : (win.curve[iNow]?.height ?? 0);
  const yn = y(hn);
  out.push(`<line class="c-now" x1="${xn.toFixed(1)}" x2="${xn.toFixed(1)}" y1="${m.top}" y2="${bottom}"/>`);
  out.push(`<circle class="c-now-dot" cx="${xn.toFixed(1)}" cy="${yn.toFixed(1)}" r="${compact ? 3.5 : 5}"/>`);
  if (!compact) {
    const right = xn < m.left + pw - 70;
    out.push(`<text class="c-now-lab" x="${(xn + (right ? 10 : -10)).toFixed(1)}" y="${(yn + 4).toFixed(1)}" text-anchor="${right ? 'start' : 'end'}">${fmtFt(hn)} ft now</text>`);
  }

  // sun / moon rail
  if (rail) {
    const glyph = compact ? 10 : 14;
    const row = (events, yTop, cls) => {
      for (const ev of events) {
        const xx = x(ev.time);
        out.push(`<use class="c-rail ${cls}" href="#i-${ev.kind}" x="${(xx - glyph / 2).toFixed(1)}" y="${yTop}" width="${glyph}" height="${glyph}"/>`);
        if (!compact) out.push(`<text class="c-rail-t" x="${xx.toFixed(1)}" y="${yTop + glyph + 11}" text-anchor="middle">${esc(fmtTimeShort(ev.time))}</text>`);
      }
    };
    if (compact) { row(win.sun, 2, 'c-sun'); row(win.moon, 2, 'c-moon'); }
    else { row(win.sun, 0, 'c-sun'); row(win.moon, 26, 'c-moon'); }
  }

  container.innerHTML = `<svg class="chart${compact ? ' chart-compact' : ''}" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" role="img" aria-label="Tide height over time">${out.join('')}<g class="c-hover" hidden><line class="c-cross" y1="${m.top}" y2="${bottom}"/><circle class="c-hover-dot" r="4"/></g></svg>`;

  if (hover) wireHover(container, win, { x, y, m, pw, extremes: ext });
}

function wireHover(container, win, s) {
  const svg = container.querySelector('svg');
  const g = svg.querySelector('.c-hover');
  const line = g.querySelector('line'), dot = g.querySelector('circle');
  let tip = container.querySelector('.c-tip');
  if (!tip) { tip = document.createElement('div'); tip.className = 'c-tip'; tip.hidden = true; container.appendChild(tip); }
  const move = ev => {
    const r = svg.getBoundingClientRect();
    const px = (ev.clientX - r.left) * (svg.viewBox.baseVal.width / r.width);
    if (px < s.m.left || px > s.m.left + s.pw) return leave();
    const t = new Date(+win.start + (px - s.m.left) / s.pw * (win.end - win.start));
    const h = heightAt(s.extremes, t);
    const xx = s.x(t), yy = s.y(h);
    line.setAttribute('x1', xx); line.setAttribute('x2', xx);
    dot.setAttribute('cx', xx); dot.setAttribute('cy', yy);
    g.hidden = false;
    tip.innerHTML = `<b>${fmtFt(h)} ft</b> ${esc(fmtTime(t))} <span>${esc(fmtWeekday(t))}</span>`;
    tip.hidden = false;
    const left = (xx / svg.viewBox.baseVal.width) * r.width;
    tip.style.left = `${left}px`;
    tip.style.top = `${(yy / svg.viewBox.baseVal.height) * r.height}px`;
    tip.classList.toggle('c-tip-flip', left > r.width - 120);
  };
  const leave = () => { g.hidden = true; tip.hidden = true; };
  svg.addEventListener('pointermove', move);
  svg.addEventListener('pointerleave', leave);
}
