import Foundation

struct Forecast: Codable, Equatable {
    struct Current: Codable, Equatable {
        let time: Date, temp: Double, feelsLike: Double
        let wind: Double, gust: Double, direction: Double
        let code: Int, isDay: Bool
    }
    struct Hour: Codable, Equatable {
        let time: Date, temp: Double, wind: Double, gust: Double, direction: Double
        let code: Int, precipChance: Int?, isDay: Bool
    }
    struct Day: Codable, Equatable {
        let date: Date, high: Double, low: Double, code: Int, windMax: Double
    }
    let current: Current
    let hourly: [Hour]
    let daily: [Day]
}

struct WeatherCondition {
    let label: String
    /// SF Symbol name
    let symbol: String
}

enum OpenMeteo {
    private static let api = "https://api.open-meteo.com/v1/forecast"

    static func url(lat: Double = Station.latitude, lng: Double = Station.longitude) -> URL {
        var c = URLComponents(string: api)!
        c.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lng)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code,is_day"),
            .init(name: "hourly", value: "temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code,precipitation_probability,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code,wind_speed_10m_max"),
            .init(name: "temperature_unit", value: "fahrenheit"),
            .init(name: "wind_speed_unit", value: "mph"),
            .init(name: "timezone", value: Station.timeZone.identifier),
            .init(name: "forecast_days", value: "3"),
        ]
        return c.url!
    }

    private static let wallFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Station.timeZone
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Station.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private struct Response: Decodable {
        struct Current: Decodable {
            let time: String
            let temperature_2m, apparent_temperature, wind_speed_10m, wind_direction_10m, wind_gusts_10m: Double
            let weather_code, is_day: Int
        }
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m, wind_speed_10m, wind_direction_10m, wind_gusts_10m: [Double]
            let weather_code, is_day: [Int]
            let precipitation_probability: [Int?]?
        }
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_max, temperature_2m_min, wind_speed_10m_max: [Double]
            let weather_code: [Int]
        }
        let current: Current
        let hourly: Hourly
        let daily: Daily
    }

    struct ParseError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func parse(_ data: Data) throws -> Forecast {
        let r = try JSONDecoder().decode(Response.self, from: data)
        func wall(_ s: String) throws -> Date {
            guard let d = wallFormatter.date(from: s) else { throw ParseError(message: "Open-Meteo: bad time \(s)") }
            return d
        }
        func day(_ s: String) throws -> Date {
            guard let d = dayFormatter.date(from: s) else { throw ParseError(message: "Open-Meteo: bad date \(s)") }
            return d
        }
        let c = r.current
        let current = Forecast.Current(time: try wall(c.time), temp: c.temperature_2m, feelsLike: c.apparent_temperature,
                                       wind: c.wind_speed_10m, gust: c.wind_gusts_10m, direction: c.wind_direction_10m,
                                       code: c.weather_code, isDay: c.is_day == 1)
        let h = r.hourly
        let hourly = try h.time.indices.map { i in
            Forecast.Hour(time: try wall(h.time[i]), temp: h.temperature_2m[i], wind: h.wind_speed_10m[i],
                          gust: h.wind_gusts_10m[i], direction: h.wind_direction_10m[i], code: h.weather_code[i],
                          precipChance: h.precipitation_probability?[i] ?? nil, isDay: h.is_day[i] == 1)
        }
        let d = r.daily
        let daily = try d.time.indices.map { i in
            Forecast.Day(date: try day(d.time[i]), high: d.temperature_2m_max[i], low: d.temperature_2m_min[i],
                         code: d.weather_code[i], windMax: d.wind_speed_10m_max[i])
        }
        return Forecast(current: current, hourly: hourly, daily: daily)
    }
}

enum Weather {
    /// WMO weather code -> label and SF Symbol.
    static func describe(code: Int, isDay: Bool = true) -> WeatherCondition {
        switch code {
        case 0: return .init(label: "Clear", symbol: isDay ? "sun.max" : "moon.stars")
        case 1: return .init(label: "Mostly clear", symbol: isDay ? "sun.max" : "moon.stars")
        case 2: return .init(label: "Partly cloudy", symbol: isDay ? "cloud.sun" : "cloud.moon")
        case 3: return .init(label: "Overcast", symbol: "cloud")
        case 45: return .init(label: "Fog", symbol: "cloud.fog")
        case 48: return .init(label: "Freezing fog", symbol: "cloud.fog")
        case 51: return .init(label: "Light drizzle", symbol: "cloud.drizzle")
        case 53: return .init(label: "Drizzle", symbol: "cloud.drizzle")
        case 55: return .init(label: "Heavy drizzle", symbol: "cloud.drizzle")
        case 56, 57: return .init(label: "Freezing drizzle", symbol: "cloud.sleet")
        case 61: return .init(label: "Light rain", symbol: "cloud.rain")
        case 63: return .init(label: "Rain", symbol: "cloud.rain")
        case 65: return .init(label: "Heavy rain", symbol: "cloud.heavyrain")
        case 66, 67: return .init(label: "Freezing rain", symbol: "cloud.sleet")
        case 71: return .init(label: "Light snow", symbol: "cloud.snow")
        case 73: return .init(label: "Snow", symbol: "cloud.snow")
        case 75: return .init(label: "Heavy snow", symbol: "cloud.snow")
        case 77: return .init(label: "Snow grains", symbol: "cloud.snow")
        case 80: return .init(label: "Light showers", symbol: "cloud.rain")
        case 81: return .init(label: "Showers", symbol: "cloud.rain")
        case 82: return .init(label: "Heavy showers", symbol: "cloud.heavyrain")
        case 85, 86: return .init(label: "Snow showers", symbol: "cloud.snow")
        case 95: return .init(label: "Thunderstorm", symbol: "cloud.bolt")
        case 96, 99: return .init(label: "Thunderstorm, hail", symbol: "cloud.bolt.rain")
        default: return .init(label: "Unknown", symbol: "cloud")
        }
    }

    private static let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                                 "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

    static func compass(_ degrees: Double) -> String {
        let d = degrees.truncatingRemainder(dividingBy: 360)
        let norm = d < 0 ? d + 360 : d
        return points[Int((norm / 22.5).rounded()) % 16]
    }
}
