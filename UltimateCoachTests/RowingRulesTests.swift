import XCTest
@testable import UltimateCoach

final class RowingRulesTests: XCTestCase {
    func testIntervalsAddRepeatOnSuccess() throws {
        XCTAssertEqual(nextRowingPrescription(previous: "6x500m/90s", success: true), "7x500m/90s")
    }

    func testZone2ProgressToThirtyMinutes() throws {
        XCTAssertEqual(nextRowingPrescription(previous: "Zone2 26-30m", success: true), "Zone2 28-30m")
    }
}

