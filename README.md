# Marshall Tides

Tide, sun, moon and wind at Marshall on Tomales Bay, in one glance. The
web page is the reference layout; `apple/` holds the iPhone app and
widgets and the Apple Watch app and complications built from it.

## Run it

**Just open it:** double-click `dist/marshall-tides.html`. It is the whole
page bundled into one file, and it fetches live data from NOAA and
Open-Meteo directly. Rebuild it after editing anything with `node build.mjs`.

**For development** the source is plain HTML and ES modules, which browsers
refuse to load from `file://`, so serve the folder:

```
python3 -m http.server 8000
```

then open http://localhost:8000. Add `?sample` to the address to see the
embedded sample data instead of live data.

To host it, turn on GitHub Pages once (Settings → Pages → Source: GitHub
Actions); `.github/workflows/pages.yml` then publishes every push to
`main`. The Claude artifact preview can't reach the internet, so it always
shows the sample.

The page re-renders every minute from its cached data and refetches the
tides and forecast every hour (or on return to a background tab once the
data is older than an hour).

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

## iPhone and Apple Watch

See [`apple/README.md`](apple/README.md). The Xcode project is generated
with XcodeGen from `apple/project.yml`; the Swift core in `apple/Shared`
is a port of the modules in `src/`, with the same tests.
