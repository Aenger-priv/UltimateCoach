import Foundation
import SwiftData
import XCTest
@testable import UltimateCoach

@MainActor
final class ExerciseTrendTests: XCTestCase {
    func testMaxEstimateUsesShortSetsAndKeepsObservedSingles() {
        let metric = ExerciseTrendMetric.estimatedMax
        XCTAssertEqual(metric.value(weight: 100, reps: 1), 100)
        XCTAssertEqual(metric.value(weight: 60, reps: 10), 80)
        XCTAssertNil(metric.value(weight: 60, reps: 11))
        XCTAssertNil(metric.value(weight: 0, reps: 8))
        XCTAssertNil(metric.value(weight: .infinity, reps: 8))
    }

    func testBodyweightTrendTreatsRepsAndAddedWeightSeparately() {
        XCTAssertEqual(ExerciseTrendMetric.bodyweightReps.value(weight: nil, reps: 7), 7)
        XCTAssertEqual(ExerciseTrendMetric.bodyweightReps.value(weight: 0, reps: 8), 8)
        XCTAssertNil(ExerciseTrendMetric.bodyweightReps.value(weight: 10, reps: 5))
        XCTAssertNil(ExerciseTrendMetric.addedWeight.value(weight: 0, reps: 10))
        XCTAssertEqual(ExerciseTrendMetric.addedWeight.value(weight: 10, reps: 5), 10)
    }

    func testTrendsGroupMatchingMovementsAcrossTracksAndKeepDeloadInHistory() throws {
        let store = try ModelContainer(for: Program.self, DayPlan.self, ExerciseTemplate.self, DayExercise.self,
            ExerciseLog.self, ProgressionRule.self, PhaseState.self, Conditioning.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = store.mainContext
        let start = Calendar.current.startOfDay(for: Date())
        let growth = try SeedData.startCycle(.hypertrophy, starts: start, context: context)
        let transition = growth.nextStartDate()
        let strength = try SeedData.startCycle(.strength, starts: transition, context: context, now: transition)

        let first = try bench(week: 1, in: growth)
        let deload = try bench(week: 13, in: growth)
        let later = try bench(week: 1, in: strength)
        let best = addSet(weight: 55, reps: 8, to: first, offset: 1, context: context)
        _ = addSet(weight: 45, reps: 10, to: first, offset: 2, context: context)
        _ = addSet(weight: 65, reps: 5, to: later, offset: 1, context: context)
        _ = addSet(weight: 30, reps: 6, to: deload, offset: 1, context: context)
        try context.save()

        let group = try XCTUnwrap(ExerciseTrendGroup.collect(from: [later.day, deload.day, first.day]).first)
        XCTAssertEqual(group.sessions.count, 3)
        let points = group.points(for: .heaviestSet)
        XCTAssertEqual(points.map(\.value), [55, 65])
        XCTAssertEqual(points.first?.date, best.timestamp)
        XCTAssertEqual(points.first?.log.reps, 8)
    }

    private func bench(week: Int, in program: Program) throws -> DayExercise {
        let day = try XCTUnwrap(program.days.first { $0.weekIdx == week && $0.dayIdx == 1 })
        return try XCTUnwrap(day.exercises.first { $0.template.name == "Bench Press" })
    }

    private func addSet(weight: Double, reps: Int, to exercise: DayExercise, offset: TimeInterval,
                        context: ModelContext) -> ExerciseLog {
        let sessionDate = exercise.day.date ?? .now
        let log = ExerciseLog(dayExercise: exercise, setIdx: exercise.logs.count + 1, actualWeight: weight,
                              reps: reps, rir: nil, timestamp: sessionDate.addingTimeInterval(offset))
        context.insert(log)
        if !exercise.logs.contains(where: { $0 === log }) { exercise.logs.append(log) }
        return log
    }
}
