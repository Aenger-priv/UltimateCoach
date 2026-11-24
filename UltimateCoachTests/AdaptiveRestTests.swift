import XCTest
import SwiftData
@testable import UltimateCoach

@MainActor
final class AdaptiveRestTests: XCTestCase {
    func testObservationOfBothActionsIsRequiredBeforeAdapting() {
        typealias Sample = AdaptiveRest.Observation
        let offered = Array(repeating: Sample(offered: true, metTarget: true), count: 4)
        let successful = Array(repeating: Sample(offered: false, metTarget: true), count: 4)
        let unsuccessful = Array(repeating: Sample(offered: false, metTarget: false), count: 4)
        XCTAssertEqual(AdaptiveRest.offerProbability(for: offered), 0.5)
        XCTAssertEqual(AdaptiveRest.offerProbability(for: offered + successful), 0.15)
        XCTAssertEqual(AdaptiveRest.offerProbability(for: offered + unsuccessful), 0.85)
    }

    func testAssignedOfferFollowsTheTimerAndOnlyLearnsFromAComparableNextSet() throws {
        let container = try ModelContainer(for: Program.self, DayPlan.self, ExerciseTemplate.self, DayExercise.self,
            ExerciseLog.self, PhaseState.self, ProgressionRule.self, Conditioning.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let program = try SeedData.startCycle(.hypertrophy, starts: .now, context: context)
        let day = try XCTUnwrap(program.days.first { $0.weekIdx == 1 && $0.dayIdx == 1 })
        let lift = try XCTUnwrap(day.exercises.first { $0.orderIdx == 0 })
        let load = try XCTUnwrap(lift.targetWeight)
        try WorkoutSession.start(day, context: context)
        func record(_ adaptive: Bool) throws -> WorkoutLogging.SavedSet {
            try WorkoutLogging.logSet(exercise: lift, kilograms: load, reps: lift.targetRepsMin, rir: 2,
                                      barbellIncrement: 2.5, dumbbellIncrement: 1, context: context,
                                      adaptiveRest: adaptive, restDraw: { 0 })
        }
        let disabled = try record(false)
        XCTAssertNil(disabled.log.restOffered)
        try WorkoutLogging.undo(disabled, context: context)
        let first = try record(true)
        XCTAssertEqual(first.log.restOfferProbability, 0.5)
        XCTAssertTrue(day.hasRestSuggestion)
        let deadline = try XCTUnwrap(day.restUntil)
        try WorkoutSession.extendRest(day, context: context, adaptiveRest: true)
        XCTAssertEqual(day.restUntil, deadline.addingTimeInterval(30))
        XCTAssertFalse(day.hasRestSuggestion)
        first.log.timestamp = .now.addingTimeInterval(-120)
        let second = try record(true)
        XCTAssertEqual(second.log.restFollowUp, true)
        // Look up the early-set context at the time of a later decision.
        XCTAssertEqual(AdaptiveRest.observations(for: lift, afterFirstSet: true, asOf: .now).map(\.metTarget), [true])
        let data = try ExportImport.exportJSON(context: context)
        try WorkoutLogging.undo(second, context: context)
        XCTAssertTrue(AdaptiveRest.observations(for: lift, afterFirstSet: true, asOf: .now).isEmpty)
        try ExportImport.importJSON(data, context: context)
        let restored = try context.fetch(FetchDescriptor<ExerciseLog>())
        XCTAssertEqual(restored.count, 2)
        XCTAssertTrue(restored.contains { $0.restOffered == true && $0.restExtended == true })
        XCTAssertTrue(restored.contains { $0.restFollowUp == true })
    }
}
