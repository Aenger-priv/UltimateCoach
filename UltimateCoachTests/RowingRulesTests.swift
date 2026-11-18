import XCTest
@testable import UltimateCoach

@MainActor
final class RowingRulesTests: XCTestCase {
    func testIntervalsAddRepeatOnSuccess() throws {
        XCTAssertEqual(nextRowingPrescription(previous: "6x500m/90s", success: true), "7x500m/90s")
    }

    func testZone2ProgressToThirtyMinutes() throws {
        XCTAssertEqual(nextRowingPrescription(previous: "Zone2 26-30m", success: true), "Zone2 28-30m")
    }
}


extension RowingRulesTests {
    func testDurationCapAndUnrecognizedProtocolsRemainStable() {
        XCTAssertEqual(nextRowingPrescription(previous: "Zone2 29-30m", success: true), "Zone2 30-30m")
        XCTAssertEqual(nextRowingPrescription(previous: "Zone2 30m", success: true), "Zone2 30m")
        XCTAssertEqual(nextRowingPrescription(previous: "Tabata 8x20/10", success: true), "Tabata 8x20/10")
        XCTAssertEqual(nextRowingPrescription(previous: "20m progressive", success: true), "20m progressive")
        XCTAssertEqual(nextRowingPrescription(previous: "Zone2 invalid", success: true), "Zone2 invalid")
    }
}
