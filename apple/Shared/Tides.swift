import Foundation

struct TideExtreme: Codable, Equatable {
    let time: Date
    let height: Double
    let isHigh: Bool
    var label: String { isHigh ? "High" : "Low" }
}

/// Where the tide is right now and what comes next.
struct TideState {
    let height: Double
    let rising: Bool
    let next: TideExtreme?
    let previous: TideExtreme?
    let upcoming: [TideExtreme]
}

enum NOAA {
    private static let api = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    /// Hi/lo predictions in GMT for the station. Marshall is a subordinate
    /// station, so highs and lows are all NOAA publishes for it.
    static func predictionsURL(begin: Date, end: Date, station: String = Station.id) -> URL {
        var c = URLComponents(string: api)!
        c.queryItems = [
            .init(name: "product", value: "predictions"),
            .init(name: "application", value: "MarshallTides"),
            .init(name: "begin_date", value: dayFormatter.string(from: begin)),
            .init(name: "end_date", value: dayFormatter.string(from: end)),
            .init(name: "datum", value: "MLLW"),
            .init(name: "station", value: station),
            .init(name: "time_zone", value: "gmt"),
            .init(name: "units", value: "english"),
            .init(name: "interval", value: "hilo"),
            .init(name: "format", value: "json"),
        ]
        return c.url!
    }

    private struct Response: Decodable {
        struct Prediction: Decodable { let t: String; let v: String; let type: String }
        struct APIError: Decodable { let message: String }
        let predictions: [Prediction]?
        let error: APIError?
    }

    struct ParseError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func parse(_ data: Data) throws -> [TideExtreme] {
        let r = try JSONDecoder().decode(Response.self, from: data)
        if let e = r.error { throw ParseError(message: "NOAA: \(e.message)") }
        guard let preds = r.predictions else { throw ParseError(message: "NOAA: no predictions") }
        return try preds.map { p in
            guard let t = timeFormatter.date(from: p.t), let v = Double(p.v) else {
                throw ParseError(message: "NOAA: bad row \(p.t) \(p.v)")
            }
            return TideExtreme(time: t, height: v, isHigh: p.type == "H")
        }.sorted { $0.time < $1.time }
    }
}

enum Tides {
    /// Height at `t`, cosine-interpolated between the neighbouring extremes,
    /// the same approximation the printed tide tables assume.
    static func height(at t: Date, in extremes: [TideExtreme]) -> Double {
        guard let first = extremes.first, let last = extremes.last else { return 0 }
        if t <= first.time { return first.height }
        for i in 1..<extremes.count {
            let a = extremes[i - 1], b = extremes[i]
            if t <= b.time {
                let f = t.timeIntervalSince(a.time) / b.time.timeIntervalSince(a.time)
                return (a.height + b.height) / 2 + (a.height - b.height) / 2 * cos(.pi * f)
            }
        }
        return last.height
    }

    struct Point { let time: Date; let height: Double }

    static func curve(_ extremes: [TideExtreme], from start: Date, to end: Date, step: TimeInterval = 6 * 60) -> [Point] {
        var pts: [Point] = []
        var t = start
        while t < end {
            pts.append(Point(time: t, height: height(at: t, in: extremes)))
            t = t.addingTimeInterval(step)
        }
        pts.append(Point(time: end, height: height(at: end, in: extremes)))
        return pts
    }

    static func state(at now: Date, in extremes: [TideExtreme]) -> TideState {
        let i = extremes.firstIndex { $0.time > now }
        let next = i.map { extremes[$0] }
        let previous = i.flatMap { $0 > 0 ? extremes[$0 - 1] : nil }
        return TideState(height: height(at: now, in: extremes),
                         rising: next?.isHigh ?? false,
                         next: next, previous: previous,
                         upcoming: i.map { Array(extremes[$0...]) } ?? [])
    }
}
