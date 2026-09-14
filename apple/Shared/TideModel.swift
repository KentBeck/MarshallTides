import Foundation

struct SkyEvent: Equatable {
    enum Kind: String { case sunrise, sunset, moonrise, moonset }
    let time: Date
    let kind: Kind
    var isSun: Bool { kind == .sunrise || kind == .sunset }
    var symbol: String {
        switch kind {
        case .sunrise: return "sunrise.fill"
        case .sunset: return "sunset.fill"
        case .moonrise: return "moonrise.fill"
        case .moonset: return "moonset.fill"
        }
    }
}

struct NightBand: Equatable { let from: Date; let to: Date }

/// Everything a chart needs for one span of time.
struct ChartWindow {
    let start: Date, end: Date, now: Date
    let curve: [Tides.Point]
    let extremes: [TideExtreme]
    let sun: [SkyEvent]
    let moon: [SkyEvent]
    let nights: [NightBand]
}

/// What was fetched, and when. Cached for an hour and shared with the widgets.
struct FetchedData: Codable, Equatable {
    let fetchedAt: Date
    let extremes: [TideExtreme]
    let forecast: Forecast
    let isSample: Bool
}

/// The view model: fetched data seen from one instant.
struct TideModel {
    let now: Date
    let data: FetchedData
    let tide: TideState
    let sun: SunTimes
    let moon: MoonTimes
    let moonIllumination: MoonIllumination
    let moonName: String
    let sunEvents: [SkyEvent]
    let moonEvents: [SkyEvent]
    let hourly: [Forecast.Hour]

    var extremes: [TideExtreme] { data.extremes }
    var weather: Forecast.Current { data.forecast.current }
    var daily: [Forecast.Day] { data.forecast.daily }
    var isDaytime: Bool { now > sun.sunrise && now < sun.sunset }
    var nextSunEvent: SkyEvent? { sunEvents.first { $0.time > now } }
    var nextMoonEvent: SkyEvent? { moonEvents.first { $0.time > now } }

    init(data: FetchedData, now: Date) {
        self.now = now
        self.data = data
        tide = Tides.state(at: now, in: data.extremes)
        sun = Astro.sunTimes(on: now)
        moon = Astro.moonTimes(on: now)
        let illum = Astro.moonIllumination(at: now)
        moonIllumination = illum
        moonName = Astro.moonPhaseName(illum.phase)

        var sunEv: [SkyEvent] = [], moonEv: [SkyEvent] = []
        for offset in -1...2 {
            let day = Station.addDays(offset, to: now)
            let s = Astro.sunTimes(on: day)
            sunEv.append(SkyEvent(time: s.sunrise, kind: .sunrise))
            sunEv.append(SkyEvent(time: s.sunset, kind: .sunset))
            let m = Astro.moonTimes(on: day)
            if let r = m.rise { moonEv.append(SkyEvent(time: r, kind: .moonrise)) }
            if let st = m.set { moonEv.append(SkyEvent(time: st, kind: .moonset)) }
        }
        sunEvents = sunEv
        moonEvents = moonEv.sorted { $0.time < $1.time }

        let from = now.addingTimeInterval(-30 * 60)
        hourly = Array(data.forecast.hourly.filter { $0.time >= from }.prefix(24))
    }

    func window(past: TimeInterval, future: TimeInterval) -> ChartWindow {
        let start = now.addingTimeInterval(-past), end = now.addingTimeInterval(future)
        let inWindow = { (t: Date) in t >= start && t <= end }
        return ChartWindow(
            start: start, end: end, now: now,
            curve: Tides.curve(data.extremes, from: start, to: end),
            extremes: data.extremes.filter { inWindow($0.time) },
            sun: sunEvents.filter { inWindow($0.time) },
            moon: moonEvents.filter { inWindow($0.time) },
            nights: Self.nightBands(sun: sunEvents, start: start, end: end))
    }

    /// [sunset, next sunrise] pairs clipped to [start, end].
    static func nightBands(sun: [SkyEvent], start: Date, end: Date) -> [NightBand] {
        var bands: [NightBand] = []
        var dusk: Date? = start // night until the first sunrise proves otherwise
        for ev in sun {
            switch ev.kind {
            case .sunset: dusk = ev.time
            case .sunrise:
                if let d = dusk, ev.time > start {
                    bands.append(NightBand(from: max(d, start), to: min(ev.time, end)))
                }
                dusk = nil
            default: break
            }
        }
        if let d = dusk, d < end { bands.append(NightBand(from: max(d, start), to: end)) }
        return bands.filter { $0.to > $0.from }
    }
}
