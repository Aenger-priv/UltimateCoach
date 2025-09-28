import XCTest
@testable import UltimateCoach

final class ProgressionEngineTests: XCTestCase {
    func testIncreaseLoadAtTopRepsAndTargetRIR() throws {
        let logs = [SetLog(weight: 60, reps: 12, rir: 2), SetLog(weight: 60, reps: 12, rir: 1.5), SetLog(weight: 60, reps: 12, rir: 1.5)]
        let target = Target(weight: 60, repMin: 8, repMax: 12, sets: 3, phase: "HYP")
        let rule = Rule(equipment: "barbell", barbellInc: 2.5, dbInc: 1.0, deloadPct: 0.10, missLimit: 3)
        let next = computeNextTargets(lastLogs: logs, lastTarget: target, rule: rule, phase: "HYP", consecutiveMisses: 0, blockStartLoad: nil)
        XCTAssertEqual(next.weight, 62.5)
    }

    func testDeloadAfterThreeMisses() throws {
        let logs = [SetLog(weight: 100, reps: 5, rir: 4), SetLog(weight: 100, reps: 4, rir: 4), SetLog(weight: 100, reps: 4, rir: 4)]
        let target = Target(weight: 100, repMin: 8, repMax: 12, sets: 3, phase: "HYP")
        let rule = Rule(equipment: "barbell", barbellInc: 2.5, dbInc: 1.0, deloadPct: 0.10, missLimit: 3)
        let next = computeNextTargets(lastLogs: logs, lastTarget: target, rule: rule, phase: "HYP", consecutiveMisses: 2, blockStartLoad: nil)
        XCTAssertEqual(next.weight, 90.0)
    }
}

