import Foundation
import XCTest
@testable import UltimateCoach

final class PeriodizationFSMTests: XCTestCase {
    private let trainingEnds = Date(timeIntervalSince1970: 100)
    private let cycleEnds = Date(timeIntervalSince1970: 200)

    func testStageBoundaries() {
        XCTAssertEqual(stage(at: 99), .training)
        XCTAssertEqual(stage(at: 100), .deload)
        XCTAssertEqual(stage(at: 199), .deload)
        XCTAssertEqual(stage(at: 200), .readyForNextTrack)
    }

    func testActiveWorkoutBlocksRolloverAndLegacyHasNoImplicitDeload() {
        XCTAssertEqual(stage(at: 200, active: true), .deload)
        XCTAssertEqual(stage(at: 100, deload: false), .training)
        XCTAssertEqual(stage(at: 200, deload: false, active: true), .training)
        XCTAssertEqual(stage(at: 200, deload: false), .readyForNextTrack)
    }

    func testLoadSuggestionsStayLighterAndAccountForHigherReps() {
        XCTAssertEqual(TrainingCycle.startingLoad(previousWeight: 100, previousReps: 5, targetReps: 3), 90)
        XCTAssertLessThan(TrainingCycle.startingLoad(previousWeight: 100, previousReps: 3, targetReps: 12), 90)
        XCTAssertNil(TrainingCycle.recoveryLoad(from: nil))
        XCTAssertEqual(TrainingCycle.recoveryLoad(from: 50), 42.5)
    }

    private func stage(at time: TimeInterval, deload: Bool = true, active: Bool = false) -> TrainingCycle.Stage {
        TrainingCycle.stage(on: Date(timeIntervalSince1970: time), trainingEnds: trainingEnds, cycleEnds: cycleEnds,
            hasDeload: deload, hasActiveWorkout: active)
    }
}
