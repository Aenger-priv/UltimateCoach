import XCTest
@testable import UltimateCoach

@MainActor
final class OneRMTests: XCTestCase {
    func testEstimateRejectsInvalidInputs() {
        XCTAssertEqual(epley1RM(weight: -10, reps: 8), 0)
        XCTAssertEqual(epley1RM(weight: 60, reps: 0), 0)
        XCTAssertEqual(epley1RM(weight: 60, reps: 10), 80, accuracy: 0.001)
    }
}
