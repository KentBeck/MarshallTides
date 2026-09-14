import XCTest

final class AstroTests: XCTestCase {
    private func wall(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return Station.calendar.date(from: c)!
    }

    private func assertNear(_ actual: Date?, _ expected: Date, minutes: Double, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("nil date", file: file, line: line) }
        XCTAssertLessThanOrEqual(abs(actual.timeIntervalSince(expected)), minutes * 60,
                                 "\(Fmt.time(actual)) not within \(minutes)m of \(Fmt.time(expected))", file: file, line: line)
    }

    // Reference times from a published almanac for Marshall. Good to a few minutes.
    func testSunTimes13And14Sep2026() {
        let s13 = Astro.sunTimes(on: wall(2026, 9, 13, 12, 0))
        assertNear(s13.sunrise, wall(2026, 9, 13, 6, 53), minutes: 3)
        assertNear(s13.sunset, wall(2026, 9, 13, 19, 22), minutes: 3)
        let s14 = Astro.sunTimes(on: wall(2026, 9, 14, 12, 0))
        assertNear(s14.sunrise, wall(2026, 9, 14, 6, 53), minutes: 3)
    }

    func testMoonTimes13And14Sep2026() {
        let m13 = Astro.moonTimes(on: wall(2026, 9, 13, 12, 0))
        assertNear(m13.set, wall(2026, 9, 13, 20, 28), minutes: 10)
        let m14 = Astro.moonTimes(on: wall(2026, 9, 14, 12, 0))
        assertNear(m14.rise, wall(2026, 9, 14, 10, 44), minutes: 3)
    }

    func testYoungWaxingCrescent() {
        let i = Astro.moonIllumination(at: wall(2026, 9, 13, 12, 0))
        XCTAssert(i.phase > 0.03 && i.phase < 0.12, "phase \(i.phase)")
        XCTAssertEqual(Astro.moonPhaseName(i.phase), "Waxing crescent")
    }

    func testPhaseNames() {
        XCTAssertEqual(Astro.moonPhaseName(0.005), "New moon")
        XCTAssertEqual(Astro.moonPhaseName(0.25), "First quarter")
        XCTAssertEqual(Astro.moonPhaseName(0.4), "Waxing gibbous")
        XCTAssertEqual(Astro.moonPhaseName(0.5), "Full moon")
        XCTAssertEqual(Astro.moonPhaseName(0.6), "Waning gibbous")
        XCTAssertEqual(Astro.moonPhaseName(0.9), "Waning crescent")
    }
}
