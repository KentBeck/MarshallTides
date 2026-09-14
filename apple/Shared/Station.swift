import Foundation

/// The one place the app knows about: NOAA subordinate station 9415625,
/// Marshall, Tomales Bay. Times are always Pacific.
enum Station {
    static let id = "9415625"
    static let name = "Marshall, Tomales Bay"
    static let shortName = "Marshall"
    static let latitude = 38.1616
    static let longitude = -122.8886
    static let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    /// Change this to match your team's App Group (also in the entitlements files).
    static let appGroup = "group.com.kentbeck.marshalltides"

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }
    static func addDays(_ n: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: n, to: startOfDay(date)) ?? date
    }
}
