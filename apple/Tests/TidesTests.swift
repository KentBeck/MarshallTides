import XCTest

final class TidesTests: XCTestCase {
    private let noaaJSON = """
    {"predictions":[
      {"t":"2026-09-13 13:50","v":"1.900","type":"L"},
      {"t":"2026-09-13 07:40","v":"5.400","type":"H"},
      {"t":"2026-09-13 20:10","v":"6.300","type":"H"}
    ]}
    """.data(using: .utf8)!

    func testParseSortsAndReadsGMT() throws {
        let ex = try NOAA.parse(noaaJSON)
        XCTAssertEqual(ex.count, 3)
        XCTAssertEqual(ex[0].time, ISO8601DateFormatter().date(from: "2026-09-13T07:40:00Z"))
        XCTAssertTrue(ex[0].isHigh)
        XCTAssertEqual(ex[1].height, 1.9)
    }

    func testParseSurfacesAPIError() {
        let bad = #"{"error":{"message":"No Predictions data was found."}}"#.data(using: .utf8)!
        XCTAssertThrowsError(try NOAA.parse(bad))
    }

    func testInterpolationHitsExtremesAndMidpoint() throws {
        let ex = try NOAA.parse(noaaJSON)
        XCTAssertEqual(Tides.height(at: ex[0].time, in: ex), 5.4, accuracy: 1e-9)
        XCTAssertEqual(Tides.height(at: ex[1].time, in: ex), 1.9, accuracy: 1e-9)
        let mid = ex[0].time.addingTimeInterval(ex[1].time.timeIntervalSince(ex[0].time) / 2)
        XCTAssertEqual(Tides.height(at: mid, in: ex), 3.65, accuracy: 1e-9)
    }

    func testStateReportsDirectionAndNext() throws {
        let ex = try NOAA.parse(noaaJSON)
        let now = ISO8601DateFormatter().date(from: "2026-09-13T18:30:00Z")!
        let s = Tides.state(at: now, in: ex)
        XCTAssertTrue(s.rising)
        XCTAssertEqual(s.next?.height, 6.3)
        XCTAssertEqual(s.previous?.height, 1.9)
    }

    func testPredictionsURL() {
        let u = NOAA.predictionsURL(begin: ISO8601DateFormatter().date(from: "2026-09-12T18:00:00Z")!,
                                    end: ISO8601DateFormatter().date(from: "2026-09-15T18:00:00Z")!).absoluteString
        XCTAssert(u.contains("station=9415625"))
        XCTAssert(u.contains("begin_date=20260912"))
        XCTAssert(u.contains("end_date=20260915"))
        XCTAssert(u.contains("time_zone=gmt"))
        XCTAssert(u.contains("interval=hilo"))
    }

    func testSampleIsCoherentAroundNow() {
        let now = Date()
        let d = Sample.data(now: now)
        let m = TideModel(data: d, now: now)
        XCTAssertNotNil(m.tide.next)
        XCTAssertNotNil(m.tide.previous)
        XCTAssertEqual(m.hourly.count, 24)
        let w = m.window(past: 6 * 3600, future: 30 * 3600)
        XCTAssertFalse(w.extremes.isEmpty)
        XCTAssertFalse(w.nights.isEmpty)
    }

    func testFetchedDataRoundTripsThroughStore() {
        let defaults = UserDefaults(suiteName: "MarshallTidesTests")!
        defaults.removePersistentDomain(forName: "MarshallTidesTests")
        let store = DataStore(defaults: defaults)
        let d = Sample.data(now: Date())
        store.save(d)
        XCTAssertEqual(store.cached(), d)
    }
}
