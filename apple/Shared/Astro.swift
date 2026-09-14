import Foundation

/// Sun and moon rise/set, position and phase. A port of the SunCalc
/// algorithms (after Meeus). Good to a few minutes.
struct SunTimes {
    let sunrise: Date, sunset: Date, dawn: Date, dusk: Date, solarNoon: Date
    var daylight: TimeInterval { sunset.timeIntervalSince(sunrise) }
}

struct MoonTimes {
    var rise: Date?
    var set: Date?
    var alwaysUp = false
    var alwaysDown = false
}

struct MoonIllumination {
    /// 0...1 lit
    let fraction: Double
    /// 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter
    let phase: Double
    let angle: Double
}

enum Astro {
    private static let rad = Double.pi / 180
    private static let J1970 = 2440588.0, J2000 = 2451545.0
    private static let e = rad * 23.4397 // obliquity of the Earth

    private static func toJulian(_ d: Date) -> Double { d.timeIntervalSince1970 / 86400 - 0.5 + J1970 }
    private static func fromJulian(_ j: Double) -> Date { Date(timeIntervalSince1970: (j + 0.5 - J1970) * 86400) }
    private static func toDays(_ d: Date) -> Double { toJulian(d) - J2000 }

    private static func rightAscension(_ l: Double, _ b: Double) -> Double {
        atan2(sin(l) * cos(e) - tan(b) * sin(e), cos(l))
    }
    private static func declination(_ l: Double, _ b: Double) -> Double {
        asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l))
    }
    private static func azimuth(_ H: Double, _ phi: Double, _ dec: Double) -> Double {
        atan2(sin(H), cos(H) * sin(phi) - tan(dec) * cos(phi))
    }
    private static func altitude(_ H: Double, _ phi: Double, _ dec: Double) -> Double {
        asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H))
    }
    private static func siderealTime(_ d: Double, _ lw: Double) -> Double { rad * (280.16 + 360.9856235 * d) - lw }
    private static func astroRefraction(_ h0: Double) -> Double {
        let h = max(h0, 0)
        return 0.0002967 / tan(h + 0.00312536 / (h + 0.08901179))
    }

    private static func solarMeanAnomaly(_ d: Double) -> Double { rad * (357.5291 + 0.98560028 * d) }
    private static func eclipticLongitude(_ M: Double) -> Double {
        let C = rad * (1.9148 * sin(M) + 0.02 * sin(2 * M) + 0.0003 * sin(3 * M))
        let P = rad * 102.9372
        return M + C + P + .pi
    }
    private static func sunCoords(_ d: Double) -> (dec: Double, ra: Double) {
        let M = solarMeanAnomaly(d), L = eclipticLongitude(M)
        return (declination(L, 0), rightAscension(L, 0))
    }

    static func sunPosition(at date: Date, lat: Double, lng: Double) -> (azimuth: Double, altitude: Double) {
        let lw = rad * -lng, phi = rad * lat, d = toDays(date)
        let c = sunCoords(d), H = siderealTime(d, lw) - c.ra
        return (azimuth(H, phi, c.dec), altitude(H, phi, c.dec))
    }

    private static let J0 = 0.0009

    /// Sun events for the station-zone day containing `date`.
    static func sunTimes(on date: Date, lat: Double = Station.latitude, lng: Double = Station.longitude) -> SunTimes {
        let noon = Station.startOfDay(date).addingTimeInterval(12 * 3600)
        let lw = rad * -lng, phi = rad * lat, d = toDays(noon)
        let n = (d - J0 - lw / (2 * .pi)).rounded()
        let ds = J0 + lw / (2 * .pi) + n
        let M = solarMeanAnomaly(ds), L = eclipticLongitude(M), dec = declination(L, 0)
        let Jnoon = J2000 + ds + 0.0053 * sin(M) - 0.0069 * sin(2 * L)
        func pair(_ angle: Double) -> (Date, Date) {
            let w = acos((sin(angle * rad) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec)))
            let a = J0 + (w + lw) / (2 * .pi) + n
            let Jset = J2000 + a + 0.0053 * sin(M) - 0.0069 * sin(2 * L)
            return (fromJulian(Jnoon - (Jset - Jnoon)), fromJulian(Jset))
        }
        let (sunrise, sunset) = pair(-0.833)
        let (dawn, dusk) = pair(-6)
        return SunTimes(sunrise: sunrise, sunset: sunset, dawn: dawn, dusk: dusk, solarNoon: fromJulian(Jnoon))
    }

    private static func moonCoords(_ d: Double) -> (ra: Double, dec: Double, dist: Double) {
        let L = rad * (218.316 + 13.176396 * d)
        let M = rad * (134.963 + 13.064993 * d)
        let F = rad * (93.272 + 13.229350 * d)
        let l = L + rad * 6.289 * sin(M)
        let b = rad * 5.128 * sin(F)
        let dt = 385001 - 20905 * cos(M)
        return (rightAscension(l, b), declination(l, b), dt)
    }

    static func moonPosition(at date: Date, lat: Double, lng: Double) -> (azimuth: Double, altitude: Double, distance: Double) {
        let lw = rad * -lng, phi = rad * lat, d = toDays(date)
        let c = moonCoords(d), H = siderealTime(d, lw) - c.ra
        var h = altitude(H, phi, c.dec)
        h += astroRefraction(h)
        return (azimuth(H, phi, c.dec), h, c.dist)
    }

    static func moonIllumination(at date: Date) -> MoonIllumination {
        let d = toDays(date), s = sunCoords(d), m = moonCoords(d), sdist = 149598000.0
        let phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra))
        let inc = atan2(sdist * sin(phi), m.dist - sdist * cos(phi))
        let angle = atan2(cos(s.dec) * sin(s.ra - m.ra),
                          sin(s.dec) * cos(m.dec) - cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra))
        return MoonIllumination(fraction: (1 + cos(inc)) / 2,
                                phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / .pi,
                                angle: angle)
    }

    /// Moon rise and set within the station-zone day containing `date`.
    static func moonTimes(on date: Date, lat: Double = Station.latitude, lng: Double = Station.longitude) -> MoonTimes {
        let t = Station.startOfDay(date), hc = 0.133 * rad
        var h0 = moonPosition(at: t, lat: lat, lng: lng).altitude - hc
        var rise: Double?, set: Double?, ye = 0.0
        var i = 1.0
        while i <= 24 {
            let h1 = moonPosition(at: t.addingTimeInterval(i * 3600), lat: lat, lng: lng).altitude - hc
            let h2 = moonPosition(at: t.addingTimeInterval((i + 1) * 3600), lat: lat, lng: lng).altitude - hc
            let a = (h0 + h2) / 2 - h1, b = (h2 - h0) / 2, xe = -b / (2 * a)
            ye = (a * xe + b) * xe + h1
            let d = b * b - 4 * a * h1
            var roots = 0, x1 = 0.0, x2 = 0.0
            if d >= 0 {
                let dx = sqrt(d) / (abs(a) * 2)
                x1 = xe - dx; x2 = xe + dx
                if abs(x1) <= 1 { roots += 1 }
                if abs(x2) <= 1 { roots += 1 }
                if x1 < -1 { x1 = x2 }
            }
            if roots == 1 {
                if h0 < 0 { rise = i + x1 } else { set = i + x1 }
            } else if roots == 2 {
                rise = i + (ye < 0 ? x2 : x1)
                set = i + (ye < 0 ? x1 : x2)
            }
            if rise != nil && set != nil { break }
            h0 = h2
            i += 2
        }
        var r = MoonTimes()
        if let rise { r.rise = t.addingTimeInterval(rise * 3600) }
        if let set { r.set = t.addingTimeInterval(set * 3600) }
        if rise == nil && set == nil {
            if ye > 0 { r.alwaysUp = true } else { r.alwaysDown = true }
        }
        return r
    }

    private static let phaseNames = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
                                     "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]

    /// Principal phases only within about half a day of exact.
    static func moonPhaseName(_ phase: Double) -> String {
        let q = phase * 8, nearest = Int(q.rounded()) % 8
        if nearest % 2 == 0 && abs(q - q.rounded()) < 0.14 { return phaseNames[nearest] }
        return phaseNames[(Int(q.rounded(.down)) % 8) | 1]
    }
}
