import XCTest
@testable import UltimateCoach

@MainActor
final class ProgressionEngineTests: XCTestCase {
    func testIncreaseLoadAtTopRepsAndTargetRIR() throws {
        let logs = [SetLog(weight: 60, reps: 12, rir: 2), SetLog(weight: 60, reps: 12, rir: 2.5), SetLog(weight: 60, reps: 12, rir: 2.5)]
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


extension ProgressionEngineTests {
    func testMissingRIRUsesPhaseDefaultAndDumbbellIncrement() {
        let logs = Array(repeating: SetLog(weight: 20, reps: 10, rir: nil), count: 3)
        let target = Target(weight: 20, repMin: 6, repMax: 10, sets: 3, phase: "STR")
        let rule = Rule(equipment: "dumbbell", barbellInc: 2.5, dbInc: 1, deloadPct: 0.1, missLimit: 3)
        XCTAssertEqual(computeNextTargets(lastLogs: logs, lastTarget: target, rule: rule, phase: "STR",
            consecutiveMisses: 0, blockStartLoad: nil).weight, 21)
    }

    func testInvalidIncrementDoesNotChangeTarget() {
        let target = Target(weight: 60, repMin: 8, repMax: 12, sets: 3, phase: "HYP")
        let rule = Rule(equipment: "barbell", barbellInc: 0, dbInc: 2, deloadPct: 0.1, missLimit: 3)
        XCTAssertEqual(computeNextTargets(lastLogs: Array(repeating: SetLog(weight: 60, reps: 12, rir: 2), count: 3),
            lastTarget: target, rule: rule, phase: "HYP", consecutiveMisses: 0, blockStartLoad: nil), target)
    }

    func testEasySetsWithinRangeDoNotCountAsMisses() {
        let target = Target(weight: 60, repMin: 8, repMax: 12, sets: 3, phase: "HYP")
        let rule = Rule(equipment: "barbell", barbellInc: 2.5, dbInc: 2, deloadPct: 0.1, missLimit: 3)
        let next = computeNextTargets(lastLogs: Array(repeating: SetLog(weight: 60, reps: 8, rir: 5), count: 3),
            lastTarget: target, rule: rule, phase: "HYP", consecutiveMisses: 2, blockStartLoad: nil)
        XCTAssertEqual(next.weight, 60)
        XCTAssertEqual(next.repMin, 8)
        XCTAssertEqual(next.repMax, 12)
    }

    func testHardTopRangeSetsHoldAndUnweightedBodyweightStaysUnweighted() {
        let rule = Rule(equipment: "barbell", barbellInc: 2.5, dbInc: 2, deloadPct: 0.1, missLimit: 3)
        let target = Target(weight: 60, repMin: 8, repMax: 12, sets: 3, phase: "HYP")
        let hard = Array(repeating: SetLog(weight: 60, reps: 12, rir: 0), count: 3)
        XCTAssertEqual(computeNextTargets(lastLogs: hard, lastTarget: target, rule: rule,
            phase: "HYP", consecutiveMisses: 0, blockStartLoad: nil), target)

        let bodyweight = Target(weight: nil, repMin: 8, repMax: 12, sets: 3, phase: "HYP")
        let easy = Array(repeating: SetLog(weight: nil, reps: 12, rir: 4), count: 3)
        XCTAssertEqual(computeNextTargets(lastLogs: easy, lastTarget: bodyweight, rule: rule,
            phase: "HYP", consecutiveMisses: 0, blockStartLoad: nil), bodyweight)
    }
}
