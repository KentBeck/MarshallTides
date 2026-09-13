# Marshall Tides

Tide, sun, moon and wind at Marshall on Tomales Bay, in one glance. This is
the web layout; it will become an iPhone widget and an Apple Watch
complication once the layout is right.

## Run it

The page is plain HTML and ES modules, no build step. Modules need a server
(browsers block them from `file://`):

```
python3 -m http.server 8000
```

then open http://localhost:8000. Add `?sample` to the address to see the
embedded sample data instead of live data.

Tests:

```
node --test test/*.test.mjs
```

## Data

- **Tides** — NOAA CO-OPS predictions for station 9415625, Marshall, Tomales
  Bay. It is a subordinate station, so NOAA publishes only highs and lows;
  the curve between them is a cosine, the same approximation the printed
  tables assume. Heights are feet above MLLW.
- **Weather** — Open-Meteo hourly forecast for the station coordinates. No
  key required.
- **Sun and moon** — computed locally in `src/astro.js` (a port of the
  SunCalc algorithms). Accurate to a few minutes; swap in a higher-precision
  ephemeris if that ever matters.

All times are shown in Pacific time regardless of where the page is viewed.

## Layout

- `index.html`, `style.css` — the page.
- `src/app.js` — loads data, falls back to the sample if the services are
  unreachable, renders everything.
- `src/model.js` — the view model: current tide, next events, sky events
  and night bands for any chart window.
- `src/chart.js` — the tide chart (SVG). Used at full size on the page and
  in compact mode inside the widget mockups.
- `src/widgets.js` — iPhone (small, medium, large), lock screen and Apple
  Watch mockups at true point sizes.

## Next steps

1. **iPhone widget** — the quickest route is [Scriptable](https://scriptable.app):
   its widgets are JavaScript, so `astro.js`, `tides.js` and `weather.js`
   port almost unchanged and the layout above is the spec.
2. **Apple Watch** — Scriptable has no watch support, so the watch needs a
   small SwiftUI app with WidgetKit complications. The same Swift target can
   also host the iPhone widgets, replacing the Scriptable version.
