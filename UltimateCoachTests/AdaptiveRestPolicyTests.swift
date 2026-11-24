import XCTest
@testable import UltimateCoach

@MainActor
final class AdaptiveRestPolicyTests: XCTestCase {
    private typealias Sample = AdaptiveRest.Observation

    func testKnownHistoriesSelectTheExpectedArmAtTheExplorationBoundaries() {
        struct Scenario {
            let name: String
            let offerWins: Int
            let offerCount: Int
            let usualWins: Int
            let usualCount: Int
            let probability: Double
        }
        let cases = [
            Scenario(name: "cold start", offerWins: 0, offerCount: 0, usualWins: 0, usualCount: 0, probability: 0.5),
            Scenario(name: "sparse control", offerWins: 8, offerCount: 8, usualWins: 0, usualCount: 3, probability: 0.5),
            Scenario(name: "helpful", offerWins: 3, offerCount: 4, usualWins: 1, usualCount: 4, probability: 0.85),
            Scenario(name: "harmful", offerWins: 1, offerCount: 4, usualWins: 3, usualCount: 4, probability: 0.15),
            Scenario(name: "both succeed", offerWins: 4, offerCount: 4, usualWins: 4, usualCount: 4, probability: 0.15),
            Scenario(name: "both fail", offerWins: 0, offerCount: 4, usualWins: 0, usualCount: 4, probability: 0.15),
            Scenario(name: "exact margin", offerWins: 2, offerCount: 8, usualWins: 1, usualCount: 8, probability: 0.15),
            Scenario(name: "just above margin", offerWins: 2, offerCount: 7, usualWins: 1, usualCount: 8, probability: 0.85)
        ]
        for row in cases {
            let history = (0..<row.offerCount).map { Sample(offered: true, metTarget: $0 < row.offerWins) }
                + (0..<row.usualCount).map { Sample(offered: false, metTarget: $0 < row.usualWins) }
            let probability = AdaptiveRest.offerProbability(for: history)
            XCTAssertEqual(probability, row.probability, row.name)
            // Sweep all one-percent bins using the same selection rule as the shipping timer.
            let offers = (0..<100).filter { index in
                AdaptiveRest.selectOffer(probability: probability, draw: (Double(index) + 0.5) / 100)
            }
            XCTAssertEqual(offers.count, Int((row.probability * 100).rounded()), row.name)
            XCTAssertFalse(AdaptiveRest.selectOffer(probability: probability, draw: probability), row.name)
        }
    }

    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    private func exercise(in program: Program, week: Int, phase: String = "HYP") -> DayExercise {
        let day = DayPlan(program: program, weekIdx: week, dayIdx: 1)
        day.startedAt = start
        if !program.days.contains(where: { $0 === day }) { program.days.append(day) }
        let template = ExerciseTemplate(name: "Bench", muscleGroup: "Chest", equipment: "barbell",
                                        defaultSets: 4, repMin: 6, repMax: 10, restSec: 90)
        let lift = DayExercise(day: day, template: template, targetWeight: 50, targetRepsMin: 6,
                               targetRepsMax: 10, sets: 4, orderIdx: 0, phase: phase)
        if !day.exercises.contains(where: { $0 === lift }) { day.exercises.append(lift) }
        return lift
    }

    private func log(_ lift: DayExercise, index: Int, seconds: Double, weight: Double = 50,
                     reps: Int = 8, rir: Double? = 2) -> ExerciseLog {
        let log = ExerciseLog(dayExercise: lift, setIdx: index, actualWeight: weight, reps: reps,
                              rir: rir, timestamp: start.addingTimeInterval(seconds))
        if !lift.logs.contains(where: { $0 === log }) { lift.logs.append(log) }
        return log
    }

    func testOpposingSetContextsSelectDifferentActionsForTheSameDraw() {
        let program = Program(name: "Test", startDate: start, totalWeeks: 13)
        program.deloadWeek = 13
        for week in 1...8 {
            let lift = exercise(in: program, week: week)
            let offered = week <= 4
            let first = log(lift, index: 1, seconds: Double(week * 1000))
            first.restOffered = offered
            // Early offers help. Later offers hurt. Use actual load/reps/RIR to generate rewards.
            let second = log(lift, index: 2, seconds: Double(week * 1000 + 100), reps: offered ? 8 : 5)
            AdaptiveRest.linkFollowUp(second, previous: first)
            second.restOffered = offered
            let third = log(lift, index: 3, seconds: Double(week * 1000 + 200), rir: offered ? 0 : nil)
            AdaptiveRest.linkFollowUp(third, previous: second)
        }
        for (week, phase, seconds) in [(9, "STR", 9000), (13, "HYP", 9000), (11, "HYP", 30000)] {
            let lift = exercise(in: program, week: week, phase: phase)
            let first = log(lift, index: 1, seconds: Double(seconds))
            first.restOffered = true
            let next = log(lift, index: 2, seconds: Double(seconds + 90), weight: 45)
            AdaptiveRest.linkFollowUp(next, previous: first)
        }
        let lift = exercise(in: program, week: 10)
        let first = log(lift, index: 1, seconds: 20000)
        let later = log(lift, index: 2, seconds: 20100)
        for (set, expectedOffer, expectedP) in [(first, true, 0.85), (later, false, 0.15)] {
            let history = AdaptiveRest.observations(for: lift, afterFirstSet: set.setIdx == 1, asOf: set.timestamp)
            XCTAssertEqual(history.count, 8)
            XCTAssertEqual(history.filter { $0.metTarget == $0.offered }.count, expectedOffer ? 8 : 0)
            AdaptiveRest.assign(after: set, draw: 0.50)
            XCTAssertEqual(set.restOffered, expectedOffer)
            XCTAssertEqual(set.restOfferProbability, expectedP)
            AdaptiveRest.assign(after: set, draw: expectedOffer ? 0.99 : 0.01)
            XCTAssertEqual(set.restOffered, expectedOffer, "A stored decision cannot be rerolled")
        }
    }

    func testEligibilityAndMissingFeedback() {
        let program = Program(name: "Test", startDate: start, totalWeeks: 13)
        program.deloadWeek = 13
        let lift = exercise(in: program, week: 1)
        let first = log(lift, index: 1, seconds: 0, reps: 9, rir: nil)
        AdaptiveRest.assign(after: first, draw: 0)
        XCTAssertNil(first.restOffered)
        let drop = log(lift, index: 2, seconds: 100, reps: 8, rir: nil)
        AdaptiveRest.assign(after: drop, draw: 0)
        XCTAssertEqual(drop.restOffered, true, "A rep drop at the same weight works without an effort rating")
        let tooSoon = log(lift, index: 3, seconds: 109, weight: 45)
        AdaptiveRest.assign(after: tooSoon, draw: 0)
        XCTAssertNil(tooSoon.restOffered)
        for seconds in [109.0, 1001.0, 110.0, 1000.0] {
            tooSoon.timestamp = start.addingTimeInterval(seconds)
            tooSoon.restFollowUp = nil
            AdaptiveRest.linkFollowUp(tooSoon, previous: drop)
            XCTAssertEqual(tooSoon.restFollowUp == true, (110...1000).contains(seconds))
        }
        let others = exercise(in: program, week: 2)
        let unrelated = log(others, index: 3, seconds: 200)
        AdaptiveRest.linkFollowUp(unrelated, previous: drop)
        XCTAssertNil(unrelated.restFollowUp)
        let finalSet = log(lift, index: 4, seconds: 500)
        AdaptiveRest.assign(after: finalSet, draw: 0)
        XCTAssertNil(finalSet.restOffered)
        let deload = log(exercise(in: program, week: 13), index: 1, seconds: 0)
        AdaptiveRest.assign(after: deload, draw: 0)
        XCTAssertNil(deload.restOffered)
        let history = AdaptiveRest.observations(for: lift, afterFirstSet: false, asOf: .distantFuture)
        XCTAssertEqual(history.map(\.metTarget), [false], "A lighter follow-up misses the prescribed load")
    }
}
