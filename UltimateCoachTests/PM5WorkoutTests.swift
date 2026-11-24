import XCTest
@testable import UltimateCoach

@MainActor
final class PM5WorkoutTests: XCTestCase {
    func testCurrentAndLegacyPrescriptionsRetainTheirExactWorkAndRest() throws {
        let short = try XCTUnwrap(RowingPrescription("Easy row · 15–20 minutes"))
        XCTAssertEqual(short.minuteRange, 15...20)
        XCTAssertEqual(short.workout, .single(.time(seconds: 900)))
        XCTAssertEqual(short.workout(minutes: 19), .single(.time(seconds: 1140)))
        XCTAssertEqual(short.workout(minutes: 21), short.workout)
        XCTAssertEqual(RowingPrescription("Easy row · 20–25 minutes")?.minuteRange, 20...25)
        XCTAssertEqual(RowingPrescription("Zone2 25-30m")?.minuteRange, 25...30)
        XCTAssertEqual(RowingPrescription("20m progressive")?.workout, .single(.time(seconds: 1200)))
        XCTAssertEqual(RowingPrescription("6x500m/90s")?.workout, .intervals(count: 6, work: .distance(meters: 500), restSeconds: 90))
        XCTAssertEqual(RowingPrescription("Tabata 8x20/10")?.workout, .intervals(count: 8, work: .time(seconds: 20), restSeconds: 10))
    }

    func testExactUnitsAndUnsupportedPrescriptions() {
        XCTAssertEqual(RowingPrescription("2000m")?.workout, .single(.distance(meters: 2000)))
        XCTAssertEqual(RowingPrescription("20 minutes")?.workout, .single(.time(seconds: 1200)))
        XCTAssertEqual(RowingPrescription("100 calories")?.workout, .single(.calories(100)))
        XCTAssertEqual(RowingPrescription("4 × 25cal / 60s")?.workout, .intervals(count: 4, work: .calories(25), restSeconds: 60))
        for text in ["Intervals as desired", "20m", "Zone2 30-25m", "6x500m/1000s", "51x500m/90s",
                     "6x20s/10s followed by 2k", "Easy row · 20–9999999999999999999999999999 minutes"] {
            XCTAssertNil(RowingPrescription(text), text)
        }
    }

    func testTimeAndCalorieFramesMatchPublishedConcept2Examples() throws {
        let time = try XCTUnwrap(PM5Command.program(.single(.time(seconds: 1200))).first)
        XCTAssertEqual(Array(time.frame), [0xF1,0x76,0x18,1,1,5,3,5,0,0,1,0xD4,0xC0,5,5,0,0,0,0x5D,0xC0,0x14,1,1,0x13,2,1,1,0xE0,0xF2])
        let calories = try XCTUnwrap(PM5Command.program(.single(.calories(100))).first)
        XCTAssertEqual(Array(calories.frame), [0xF1,0x76,0x18,1,1,10,3,5,0x40,0,0,0,100,5,5,0x40,0,0,0,20,0x14,1,1,0x13,2,1,1,0x17,0xF2])
        let distance = try XCTUnwrap(PM5Command.program(.single(.distance(meters: 2000))).first)
        XCTAssertEqual(Array(distance.frame), [0xF1,0x76,0x18,1,1,3,3,5,0x80,0,0,7,0xD0,5,5,0x80,0,0,1,0x90,0x14,1,1,0x13,2,1,1,0x28,0xF2])
    }

    func testIntervalFramesAreFiniteAndOnlyPrepareMonitorOnce() throws {
        let commands = PM5Command.program(.intervals(count: 6, work: .distance(meters: 500), restSeconds: 90))
        XCTAssertEqual(commands.count, 6)
        XCTAssertEqual(commands.first?.frame, PM5Command.frame([0x76,23,0x18,1,0,1,1,8,0x17,1,1,3,5,0x80,0,0,1,0xF4,4,2,0,90,0x14,1,1]))
        XCTAssertEqual(commands.last?.frame, PM5Command.frame([0x76,24,0x18,1,5,0x17,1,1,3,5,0x80,0,0,1,0xF4,4,2,0,0,0x14,1,1,0x13,2,1,1]))
        XCTAssertTrue(PM5Command.program(.intervals(count: 99, work: .time(seconds: 20), restSeconds: 10)).isEmpty)
        XCTAssertTrue(PM5Command.program(.single(.time(seconds: Int.max))).isEmpty)
    }

    func testOnlyCompleteMatchingMonitorResponsesAreAccepted() throws {
        let check = PM5Command.checkMonitor
        XCTAssertEqual(check.response(to: PM5Command.frame([1,0x7E,3,0x8D,1,0])), .accepted)
        XCTAssertEqual(check.response(to: PM5Command.frame([1,0x7E,3,0x8D,1,3])), .busy)
        let confirm = PM5Command.confirmType(of: .single(.time(seconds: 1200)))
        XCTAssertEqual(confirm.response(to: PM5Command.frame([1,0x7E,3,0x89,1,5])), .accepted)
        XCTAssertEqual(confirm.response(to: PM5Command.frame([1,0x7E,3,0x89,1,8])), .invalid)
        let setup = try XCTUnwrap(PM5Command.program(.single(.time(seconds: 1200))).first)
        let accepted = Data([0xF1,0x81,0x76,5,1,3,5,0x14,0x13,0xF3,2,0xF2])
        XCTAssertEqual(setup.response(to: accepted), .accepted)
        XCTAssertEqual(check.response(to: accepted), .invalid)
        XCTAssertEqual(setup.response(to: accepted.dropLast()), .invalid)
        var corrupt = accepted
        corrupt[4] = 2
        XCTAssertEqual(setup.response(to: corrupt), .invalid)
        XCTAssertEqual(setup.response(to: PM5Command.frame([0x91,0x76,5,1,3,5,0x14,0x13])), .invalid)
    }
}
