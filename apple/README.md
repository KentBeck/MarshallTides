# Marshall Tides for iPhone and Apple Watch

Native versions of the web layout: an iPhone app with home-screen and
lock-screen widgets, and an Apple Watch app with complications. One shared
core (`Shared/`) does the astronomy, tide interpolation, weather parsing and
chart drawing for all of them; it is a line-for-line port of the web
modules in `../src`.

## Build

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen), so no `.xcodeproj`
is checked in:

```
brew install xcodegen
cd apple
xcodegen generate
open MarshallTides.xcodeproj
```

Then in Xcode:

1. Select your team under Signing & Capabilities for each of the five
   targets (or set `DEVELOPMENT_TEAM` once in `project.yml` and regenerate).
2. The targets share an App Group, `group.com.kentbeck.marshalltides`, so
   the app and widgets read one cached copy of the data. If Xcode can't
   register that group under your team, rename it in `project.yml` and in
   `Shared/Station.swift`.
3. Run the `MarshallTides` scheme on an iPhone; the watch app installs
   alongside it. Run `MarshallTidesWatch` directly to debug the watch.

Tests (`Tests/`) run against the shared core: Product → Test, or
`xcodebuild test -scheme MarshallTides -destination 'platform=iOS Simulator,name=iPhone 16'`.

This code was written without Xcode at hand, so expect the first build to
surface a few compiler complaints to tidy. The logic is tested in
JavaScript form on the web page and the Swift tests mirror those checks.

## Refresh cadence

- **Apps** re-render every minute (`TimelineView(.everyMinute)`) and
  refetch every hour, or when they return to the foreground with data
  older than an hour.
- **Widgets** get a timeline of entries five minutes apart for the next
  hour from one fetch, then ask again; the shared store refetches only when
  its copy is an hour old, so the app and all widgets share one request per
  hour. Countdowns in the widgets are static text at each entry; if you
  want them to tick, swap them for `Text(date, style: .relative)`.

## Targets

| Target | What |
|---|---|
| `MarshallTides` | iPhone app: now strip, chart, hourly strip, tide table |
| `MarshallTidesWidget` | Home screen small/medium/large, lock screen inline/rectangular/circular |
| `MarshallTidesWatch` | Watch app: tide page and sky page |
| `MarshallTidesWatchWidget` | Complications: inline, rectangular, circular, corner |
| `MarshallTidesTests` | Astronomy, tide and store tests |

## Data

Identical to the web page: NOAA CO-OPS hi/lo predictions for subordinate
station 9415625 with cosine interpolation between extremes, Open-Meteo for
weather, sun and moon computed on device. If neither service can be
reached and nothing is cached, a labeled sample keeps the widgets drawing.
