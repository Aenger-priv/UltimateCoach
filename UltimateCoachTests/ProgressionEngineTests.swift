import XCTest
@testable import UltimateCoach

@MainActor
final class ProgressionEngineTests: XCTestCase {
    private let rule = Rule(equipment: "barbell", barbellInc: 2.5, dbInc: 2, deloadPct: 0.10, missLimit: 3)

    private func work(at weight: Double = 60, actual: Double? = nil, reps: [Int] = [12, 12, 12],
                      reserve: Double? = 2, phase: String = "HYP") -> LiftExposure {
        let strength = phase == "STR"
        let target = Target(weight: weight, repMin: strength ? 3 : 8, repMax: strength ? 5 : 12, sets: 3, phase: phase)
        let logs = reps.map { SetLog(weight: actual ?? weight, reps: $0, rir: reserve) }
        return LiftExposure(target: target, logs: logs, reserve: 2)
    }

    func testBothTracksRequireTwoComparableExposuresAndRestartConfirmationAtEachLoad() {
        for phase in ["HYP", "STR"] {
            let reps = Array(repeating: phase == "STR" ? 5 : 12, count: 3)
            let first = work(reps: reps, phase: phase)
            XCTAssertEqual(LiftRecommendation.assess(first, previous: [], rule: rule).reason, .confirmTopSets)
            let confirmed = LiftRecommendation.assess(first, previous: [first], rule: rule)
            XCTAssertEqual(confirmed.reason, .increase)
            XCTAssertEqual(confirmed.target.weight, 62.5)
            let next = work(at: 62.5, reps: reps, phase: phase)
            XCTAssertEqual(LiftRecommendation.assess(next, previous: [first, first], rule: rule).reason, .confirmTopSets)
            // Performing the old load hundreds of times never earns a further increase.
            let repeated = work(at: 62.5, actual: 60, reps: reps, phase: phase)
            XCTAssertEqual(LiftRecommendation.assess(repeated, previous: Array(repeating: repeated, count: 200),
                                                    rule: rule).target.weight, 62.5)
        }
    }

    func testConfirmationRespectsSetCountLoadReserveAndComparableHistory() {
        let top = work()
        XCTAssertEqual(work(reps: [12, 11, 12]).topSets, 2)
        for ineligible in [work(at: 55), work(reps: [12, 12]), work(actual: 50), work(reserve: 1),
                           work(reps: [12, 9, 12]), work(reps: [12, 12, 12], reserve: .nan)] {
            XCTAssertEqual(LiftRecommendation.assess(top, previous: [ineligible, top], rule: rule).reason, .confirmTopSets)
        }
        XCTAssertEqual(LiftRecommendation.assess(work(reserve: 0), previous: [top], rule: rule).reason, .recoverReserve)
        XCTAssertEqual(LiftRecommendation.assess(work(reserve: nil), previous: [top], rule: rule).reason, .increase)
    }

    func testEquipmentStepsAreAdditiveAndCappedForSmallExercisesAndAtEntryLimit() {
        let dumbbell = Rule(equipment: "dumbbell", barbellInc: 2.5, dbInc: 1, deloadPct: 0.10, missLimit: 3)
        let small = work(at: 8)
        let earned = LiftRecommendation.assess(small, previous: [small], rule: dumbbell)
        XCTAssertEqual(earned.reason, .incrementTooLarge)
        XCTAssertEqual(earned.target.weight, 8)
        let offGrid = work(at: 20.5)
        XCTAssertEqual(LiftRecommendation.assess(offGrid, previous: [offGrid], rule: dumbbell).target.weight, 21.5)
        let atLimit = work(at: 500)
        XCTAssertEqual(LiftRecommendation.assess(atLimit, previous: [atLimit], rule: dumbbell).reason, .nearEntryLimit)
    }

    func testThreeMissesAtSameWeightResetOnceAndLighterWorkDoesNotTriggerReset() {
        let miss = work(at: 100, reps: [7, 7, 7])
        XCTAssertEqual(LiftRecommendation.assess(miss, previous: [miss], rule: rule).target.weight, 100)
        let reduced = LiftRecommendation.assess(miss, previous: [miss, miss], rule: rule)
        XCTAssertEqual(reduced.reason, .reduce)
        XCTAssertEqual(reduced.target.weight, 90)
        let stillMiss = work(at: 90, reps: [7, 7, 7])
        XCTAssertEqual(LiftRecommendation.assess(stillMiss, previous: [miss, miss, miss], rule: rule).target.weight, 90)
        let light = work(at: 100, actual: 80, reps: [7, 7, 7])
        let heavy = work(at: 100, actual: 110, reps: [7, 7, 7])
        for ineligible in [light, heavy, work(at: 100, reps: [7])] {
            XCTAssertEqual(LiftRecommendation.assess(ineligible, previous: [miss, miss], rule: rule).target.weight, 100)
        }
    }

    func testFourFlatExposuresPromptReviewAndRepGainsClearTheCue() {
        let steady = work(reps: [10, 9, 8])
        XCTAssertEqual(LiftRecommendation.assess(steady, previous: [steady, steady], rule: rule).reason, .buildReps)
        let history = [steady, steady, steady]
        let review = LiftRecommendation.assess(steady, previous: history, rule: rule)
        XCTAssertEqual(review.reason, .steadyWork)
        XCTAssertEqual(review.target.weight, 60)
        let extraRep = work(reps: [10, 9, 9])
        XCTAssertEqual(LiftRecommendation.assess(extraRep, previous: history, rule: rule).reason, .buildReps)
        let changedLoad = work(actual: 65, reps: [10, 9, 8])
        XCTAssertEqual(LiftRecommendation.assess(changedLoad, previous: history, rule: rule).reason, .buildReps)
    }

    func testUnweightedExerciseAndInvalidSettingsNeverAutoAddWeight() {
        let invalid = Rule(equipment: "barbell", barbellInc: 0, dbInc: 1, deloadPct: 0.10, missLimit: 3)
        let top = work()
        XCTAssertEqual(LiftRecommendation.assess(top, previous: [top], rule: invalid).target, top.target)
        let bodyweight = Rule(equipment: "bodyweight", barbellInc: 2.5, dbInc: 1, deloadPct: 0.10, missLimit: 3)
        let exposure = LiftExposure(target: Target(weight: nil, repMin: 8, repMax: 12, sets: 3, phase: "HYP"),
                                    logs: Array(repeating: SetLog(weight: nil, reps: 12, rir: 2), count: 3), reserve: 2)
        XCTAssertEqual(LiftRecommendation.assess(exposure, previous: [exposure], rule: bodyweight).reason, .bodyweight)
    }
}
