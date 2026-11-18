import XCTest
@testable import UltimateCoach

@MainActor
final class PeriodizationFSMTests: XCTestCase {
    func testSwitchToSTRWithLowRIRAndFivePercentGain() throws {
        let history = [SetLog(weight: 60, reps: 12, rir: 1), SetLog(weight: 60, reps: 12, rir: 1)]
        let result = shouldSwitchPhase(history: history, currentPhase: "HYP", blockStartLoad: 60, currentLoad: 63)
        XCTAssertEqual(result, "STR")
    }

    func testSwitchBackToHYPOnHighRIR() throws {
        let history = [SetLog(weight: 100, reps: 4, rir: 3.5), SetLog(weight: 100, reps: 4, rir: 3.0)]
        let result = shouldSwitchPhase(history: history, currentPhase: "STR", blockStartLoad: 100, currentLoad: 100)
        XCTAssertEqual(result, "HYP")
    }
}


extension PeriodizationFSMTests {
    func testIncompleteEvidenceKeepsPhase() {
        let history = [SetLog(weight: 60, reps: 8, rir: nil)]
        XCTAssertEqual(shouldSwitchPhase(history: history, currentPhase: "HYP", blockStartLoad: nil, currentLoad: 60), "HYP")
        XCTAssertEqual(shouldSwitchPhase(history: history, currentPhase: "HYP", blockStartLoad: 60, currentLoad: 63), "HYP")
        XCTAssertEqual(shouldSwitchPhase(history: history, currentPhase: "STR", blockStartLoad: 60, currentLoad: 63), "STR")
    }
}
