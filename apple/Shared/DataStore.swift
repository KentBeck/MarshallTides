import Foundation

/// Fetches tides and weather, keeps them for an hour in the App Group so the
/// app and every widget read the same copy.
final class DataStore {
    static let shared = DataStore()
    static let maxAge: TimeInterval = 60 * 60

    private let defaults: UserDefaults
    private let key = "fetchedData.v1"

    init(defaults: UserDefaults = UserDefaults(suiteName: Station.appGroup) ?? .standard) {
        self.defaults = defaults
    }

    func cached() -> FetchedData? {
        guard let raw = defaults.data(forKey: key) else { return nil }
        return try? Self.decoder.decode(FetchedData.self, from: raw)
    }

    func save(_ data: FetchedData) {
        if let raw = try? Self.encoder.encode(data) { defaults.set(raw, forKey: key) }
    }

    /// Cached data if under an hour old; otherwise a fresh fetch. Falls back
    /// to the stale cache, then to the sample, so there is always something to draw.
    func load(now: Date = Date(), force: Bool = false) async -> FetchedData {
        if !force, let c = cached(), !c.isSample, now.timeIntervalSince(c.fetchedAt) < Self.maxAge {
            return c
        }
        do {
            let fresh = try await fetch(now: now)
            save(fresh)
            return fresh
        } catch {
            if let c = cached(), !c.isSample { return c }
            return Sample.data(now: now)
        }
    }

    func fetch(now: Date) async throws -> FetchedData {
        let session = URLSession.shared
        async let tides = session.data(from: NOAA.predictionsURL(begin: now.addingTimeInterval(-86400),
                                                                  end: now.addingTimeInterval(2 * 86400)))
        async let weather = session.data(from: OpenMeteo.url())
        let (tideData, _) = try await tides
        let (weatherData, _) = try await weather
        return FetchedData(fetchedAt: now,
                           extremes: try NOAA.parse(tideData),
                           forecast: try OpenMeteo.parse(weatherData),
                           isSample: false)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970; return d
    }()
}

/// Offline sample, shifted so its moment lines up with the clock. Plausible
/// for Tomales Bay two days after a new moon; not a forecast.
enum Sample {
    private static let anchor = ISO8601DateFormatter().date(from: "2026-09-13T18:30:00Z")!

    private static let rows: [(String, Double, Bool)] = [
        ("2026-09-12 07:10", 5.0, true), ("2026-09-12 13:00", 2.3, false),
        ("2026-09-12 19:30", 6.0, true), ("2026-09-13 02:00", 1.2, false),
        ("2026-09-13 07:40", 5.4, true), ("2026-09-13 13:50", 1.9, false),
        ("2026-09-13 20:10", 6.3, true), ("2026-09-14 02:50", 0.9, false),
        ("2026-09-14 09:30", 4.6, true), ("2026-09-14 15:40", 1.7, false),
        ("2026-09-14 21:10", 5.9, true), ("2026-09-15 04:00", 0.6, false),
        ("2026-09-15 10:40", 4.4, true), ("2026-09-15 16:40", 1.9, false),
        ("2026-09-15 22:00", 5.7, true), ("2026-09-16 04:50", 0.5, false),
    ]

    static func data(now: Date) -> FetchedData {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let shift = now.timeIntervalSince(anchor)
        let extremes = rows.map { TideExtreme(time: f.date(from: $0.0)!.addingTimeInterval(shift), height: $0.1, isHigh: $0.2) }

        // Fog until late morning, clearing, north-west wind building through the afternoon.
        let day0 = Station.startOfDay(now)
        var hours: [Forecast.Hour] = []
        var days: [Forecast.Day] = []
        for di in 0..<3 {
            let day = Station.addDays(di, to: day0)
            for h in 0..<24 {
                let warm = max(0, sin(.pi * (Double(h) - 7) / 13))
                let breeze = max(0, sin(.pi * (Double(h) - 10) / 10))
                let clearBy = di == 1 ? 13 : 11
                let code = h < clearBy - 2 ? 45 : h < clearBy ? 3 : h < clearBy + 1 ? 2 : h < 20 ? 0 : 2
                hours.append(Forecast.Hour(time: day.addingTimeInterval(Double(h) * 3600),
                                           temp: (53 + 13 * warm - Double(di)).rounded(),
                                           wind: (4 + 12 * breeze).rounded(), gust: (7 + 17 * breeze).rounded(),
                                           direction: 305 + 20 * sin(Double(h) / 3), code: code,
                                           precipChance: 0, isDay: h >= 7 && h < 19))
            }
            days.append(Forecast.Day(date: day, high: 66 - Double(di), low: 53 - Double(di) * 0.5,
                                     code: di == 1 ? 3 : 2, windMax: 16 - Double(di)))
        }
        let hour = Station.calendar.component(.hour, from: now)
        let current = Forecast.Current(time: now, temp: hours[hour].temp, feelsLike: hours[hour].temp - 2,
                                       wind: hours[hour].wind, gust: hours[hour].gust, direction: hours[hour].direction,
                                       code: hours[hour].code, isDay: hours[hour].isDay)
        return FetchedData(fetchedAt: now, extremes: extremes,
                           forecast: Forecast(current: current, hourly: hours, daily: days), isSample: true)
    }
}
