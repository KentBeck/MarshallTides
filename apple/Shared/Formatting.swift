import Foundation

/// Station-zone formatting, matching the web page.
enum Fmt {
    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = Station.timeZone
        f.dateFormat = format
        return f
    }
    private static let timeF = formatter("h:mm a")          // 1:14 PM
    private static let timeShortF = formatter("h:mma")      // 1:14PM -> 1:14p
    private static let hourShortF = formatter("ha")         // 1PM -> 1p
    private static let weekdayF = formatter("EEE")          // Mon
    private static let dayF = formatter("EEE, MMM d")       // Mon, Sep 14
    private static let longF = formatter("EEEE, MMMM d")    // Monday, September 14

    static func time(_ d: Date) -> String { timeF.string(from: d) }
    static func timeShort(_ d: Date) -> String { shortMeridiem(timeShortF.string(from: d)) }
    static func hourShort(_ d: Date) -> String { shortMeridiem(hourShortF.string(from: d)) }
    static func weekday(_ d: Date) -> String { weekdayF.string(from: d) }
    static func day(_ d: Date) -> String { dayF.string(from: d) }
    static func longDate(_ d: Date) -> String { longF.string(from: d) }

    private static func shortMeridiem(_ s: String) -> String {
        s.replacingOccurrences(of: "AM", with: "a").replacingOccurrences(of: "PM", with: "p")
    }

    static func feet(_ h: Double) -> String { String(format: "%.1f", h) }
    static func degrees(_ t: Double) -> String { "\(Int(t.rounded()))°" }
    static func mph(_ v: Double) -> String { "\(Int(v.rounded()))" }

    /// "1h 40m" or "25m"
    static func duration(_ s: TimeInterval) -> String {
        let m = Int((abs(s) / 60).rounded())
        let h = m / 60, mm = m % 60
        return h > 0 ? String(format: "%dh %02dm", h, mm) : "\(mm)m"
    }

    static func nextTide(_ t: TideExtreme, short: Bool = false) -> String {
        short ? "\(t.label) \(feet(t.height)) · \(timeShort(t.time))"
              : "\(t.label) \(feet(t.height)) ft at \(time(t.time))"
    }
}
