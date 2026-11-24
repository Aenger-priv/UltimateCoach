import Foundation
import SwiftData
import XCTest
@testable import UltimateCoach

@MainActor
final class CycleDashboardMetricsTests: XCTestCase {
    func testAttendanceAndLoggedSetsUseClosedScheduleDatesAndCountDeloadWork() throws {
        let fixture = try Fixture(track: .hypertrophy)
        let first = fixture.day(week: 1, offset: -4, finished: true)
        fixture.exercise(first, logs: [(20, 10)])
        let skipped = fixture.day(week: 2, offset: -3)
        skipped.skippedAt = fixture.now
        fixture.exercise(skipped)
        let running = fixture.day(week: 3, offset: -2)
        running.startedAt = fixture.now
        fixture.exercise(running, logs: [(20, 7), (20, 6), (20, 5)])
        let moved = fixture.day(week: 4, offset: -1)
        fixture.exercise(moved)
        fixture.exercise(fixture.day(week: 5, offset: 0))
        fixture.exercise(fixture.day(week: 6, offset: 5, finished: true), logs: [(25, 8)])
        fixture.exercise(fixture.day(week: 13, offset: -5, finished: true), logs: [(10, 5)])
        fixture.day(week: 7, offset: 7).date = nil

        var metrics = fixture.metrics
        XCTAssertEqual(metrics.workouts.finishedWorkouts, 3)
        XCTAssertEqual(metrics.workouts.totalWorkouts, 8)
        XCTAssertEqual(metrics.workouts.finishedScheduledBeforeToday, 2)
        XCTAssertEqual(metrics.workouts.scheduledBeforeToday, 5)
        XCTAssertEqual(metrics.loggedSetsScheduledBeforeToday, 4)
        XCTAssertEqual(metrics.plannedSetsScheduledBeforeToday, 10)

        moved.date = fixture.now.addingTimeInterval(86400)
        metrics = fixture.metrics
        XCTAssertEqual(metrics.workouts.scheduledBeforeToday, 4)
        XCTAssertEqual(metrics.plannedSetsScheduledBeforeToday, 8)
    }

    func testFirstDayShowsNoAdherenceCohortOrComparablePerformance() throws {
        let fixture = try Fixture(track: .strength)
        fixture.exercise(fixture.day(week: 1, offset: 0, finished: true), logs: [(50, 5)])
        let metrics = fixture.metrics
        XCTAssertEqual(metrics.workouts.finishedWorkouts, 1)
        XCTAssertEqual(metrics.workouts.scheduledBeforeToday, 0)
        XCTAssertEqual(metrics.plannedSetsScheduledBeforeToday, 0)
        XCTAssertNil(metrics.performance)
    }

    func testStrengthComparisonUsesLastTwoSessionsOfSameSlotAndExcludesDeload() throws {
        let fixture = try Fixture(track: .strength)
        fixture.exercise(fixture.day(week: 1, offset: -20, finished: true), logs: [(60, 1)])
        fixture.exercise(fixture.day(week: 2, offset: -13, finished: true), logs: [(65, 1), (200, 15)])
        fixture.exercise(fixture.day(week: 3, offset: -6, finished: true), logs: [(60, 5), (500, 11)])
        fixture.exercise(fixture.day(week: 3, slot: 4, offset: -5, finished: true), logs: [(80, 5)])
        fixture.exercise(fixture.day(week: 13, offset: -3, finished: true), logs: [(40, 3)])
        fixture.exercise(fixture.day(week: 4, offset: -2), logs: [(90, 1)])
        let performance = try XCTUnwrap(fixture.metrics.performance)
        XCTAssertEqual(performance.name, "Bench Press")
        XCTAssertEqual(performance.metric, .estimatedMax)
        XCTAssertEqual(performance.previousValue, 65)
        XCTAssertEqual(performance.latestValue, 70, accuracy: 0.0001)
    }

    func testHypertrophyShowsSameRepResultAndNeverComparesUnmatchedLoads() throws {
        let fixture = try Fixture(track: .hypertrophy)
        fixture.exercise(fixture.day(week: 1, offset: -15, finished: true), logs: [(20, 12), (25, 8), (30, 5)])
        fixture.exercise(fixture.day(week: 2, offset: -8, finished: true), logs: [(20, 14), (25, 8), (25, 7)])
        let performance = try XCTUnwrap(fixture.metrics.performance)
        XCTAssertEqual(performance.metric, .repsAtSameLoad)
        XCTAssertEqual(performance.sharedWeight, 25)
        XCTAssertEqual(performance.previousValue, 8)
        XCTAssertEqual(performance.latestValue, 8)

        fixture.exercise(fixture.day(week: 3, offset: -1, finished: true), logs: [(27.5, 10)])
        XCTAssertNil(fixture.metrics.performance)
    }

    func testHypertrophyComparesLoadAtSharedRepsWhenTheWeightChanges() throws {
        let fixture = try Fixture(track: .hypertrophy)
        fixture.exercise(fixture.day(week: 1, offset: -8, finished: true), logs: [(25, 10), (27.5, 8)])
        fixture.exercise(fixture.day(week: 2, offset: -1, finished: true), logs: [(30, 10), (32.5, 8)])
        let performance = try XCTUnwrap(fixture.metrics.performance)
        XCTAssertEqual(performance.metric, .loadAtSameReps)
        XCTAssertEqual(performance.sharedReps, 10)
        XCTAssertEqual(performance.previousValue, 25)
        XCTAssertEqual(performance.latestValue, 30)
    }

    func testUnweightedBodyweightRemainsDistinctFromLoadedRepsAndEquipmentSwaps() throws {
        let fixture = try Fixture(track: .strength)
        let day = fixture.day(week: 1, offset: -15, finished: true)
        fixture.exercise(day, name: "Pull-Up", equipment: "bodyweight", logs: [(nil, 6), (10, 2)])
        let later = fixture.day(week: 2, offset: -8, finished: true)
        fixture.exercise(later, name: "Pull-Up", equipment: "machine", logs: [(10, 9)])
        XCTAssertNil(fixture.metrics.performance)

        let final = fixture.day(week: 3, offset: -1, finished: true)
        fixture.exercise(final, name: "Pull-Up", equipment: "bodyweight", logs: [(0, 8), (5, 5)])
        let performance = try XCTUnwrap(fixture.metrics.performance)
        XCTAssertEqual(performance.metric, .repsAtSameLoad)
        XCTAssertEqual(performance.previousValue, 6)
        XCTAssertEqual(performance.latestValue, 8)
        XCTAssertNil(performance.sharedWeight)
    }

    @MainActor
    private final class Fixture {
        let store: ModelContainer
        let program: Program
        let now = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
            .addingTimeInterval(43_200)

        init(track: TrainingTrack) throws {
            store = try ModelContainer(for: Program.self, DayPlan.self, DayExercise.self, ExerciseTemplate.self,
                                       ExerciseLog.self, Conditioning.self, ProgressionRule.self, PhaseState.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            program = Program(name: track.title, startDate: now.addingTimeInterval(-30 * 86400), totalWeeks: 13)
            program.trackCode = track.rawValue
            program.deloadWeek = 13
            store.mainContext.insert(program)
        }

        var metrics: CycleDashboardMetrics { CycleDashboardMetrics(program: program, now: now) }

        func day(week: Int, slot: Int = 1, offset: Int, finished: Bool = false) -> DayPlan {
            let day = DayPlan(program: program, weekIdx: week, dayIdx: slot)
            day.date = Calendar.current.date(byAdding: .day, value: offset, to: now)
            if finished { day.finishedAt = min(day.date ?? now, now) }
            store.mainContext.insert(day)
            if !program.days.contains(where: { $0 === day }) { program.days.append(day) }
            return day
        }

        func exercise(_ day: DayPlan, name: String = "Bench Press", equipment: String = "barbell",
                      logs: [(Double?, Int)] = []) {
            let template = ExerciseTemplate(name: name, muscleGroup: "upper", equipment: equipment,
                                            defaultSets: 2, repMin: 5, repMax: 10, restSec: 120)
            let exercise = DayExercise(day: day, template: template, targetWeight: nil,
                                       targetRepsMin: 5, targetRepsMax: 10, sets: 2, orderIdx: 0,
                                       phase: program.track?.phase ?? "HYP")
            store.mainContext.insert(exercise)
            if !day.exercises.contains(where: { $0 === exercise }) { day.exercises.append(exercise) }
            for (index, value) in logs.enumerated() {
                let log = ExerciseLog(dayExercise: exercise, setIdx: index + 1, actualWeight: value.0,
                                      reps: value.1, rir: nil, timestamp: day.finishedAt ?? now)
                store.mainContext.insert(log)
                if !exercise.logs.contains(where: { $0 === log }) { exercise.logs.append(log) }
            }
        }
    }
}
