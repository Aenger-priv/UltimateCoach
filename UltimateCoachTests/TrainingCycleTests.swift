import SwiftData
import XCTest
@testable import UltimateCoach

@MainActor
final class TrainingCycleTests: XCTestCase {
    private let date = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))

    func testTemplatesMatchTrackGoalsAndScheduleDeload() throws {
        let growthStore = try store()
        let strengthStore = try store()
        let hypertrophy = try SeedData.startCycle(.hypertrophy, starts: date, context: growthStore.mainContext)
        let strength = try SeedData.startCycle(.strength, starts: date, context: strengthStore.mainContext)
        let week = hypertrophy.days.filter { $0.weekIdx == 1 }.flatMap(\.exercises)
        XCTAssertEqual(week.reduce(0) { $0 + $1.sets }, 68)
        for muscle in ["chest", "back", "quads", "hamstrings"] {
            XCTAssertGreaterThanOrEqual(week.filter { $0.template.muscleGroup == muscle }.reduce(0) { $0 + $1.sets }, 10)
        }
        for program in [hypertrophy, strength] {
            XCTAssertEqual(program.totalWeeks, 13)
            XCTAssertEqual(program.days.count, 52)
            XCTAssertEqual(program.days.filter(\.isDeload).count, 4)
            XCTAssertTrue(program.days.filter(\.isDeload).allSatisfy { $0.conditioning == nil })
            for day in program.days where day.isDeload {
                let regularDay = try XCTUnwrap(program.days.first { $0.weekIdx == 12 && $0.dayIdx == day.dayIdx })
                XCTAssertLessThan(day.plannedSets, regularDay.plannedSets)
            }
        }
        let bench = try XCTUnwrap(lift("Bench Press", day: 1, week: 1, in: strength))
        XCTAssertEqual(bench.phase, "STR")
        XCTAssertEqual(bench.targetRepsMin, 3)
        XCTAssertEqual(bench.targetRepsMax, 5)
        XCTAssertEqual(bench.restSeconds, 210)
        let secondBench = try XCTUnwrap(lift("Bench Press", day: 4, week: 1, in: strength))
        XCTAssertEqual(secondBench.targetRepsMin, 4)
    }

    func testRolloverArchivesHistoryAndBackupPreservesBothTracks() throws {
        let container = try store()
        let context = container.mainContext
        let first = try SeedData.startCycle(.hypertrophy, starts: date, context: context)
        let finalBench = try XCTUnwrap(lift("Bench Press", day: 1, week: 12, in: first))
        let recoveryBench = try XCTUnwrap(lift("Bench Press", day: 1, week: 13, in: first))
        XCTAssertEqual(first.track?.alternate, .strength)
        let transition = first.nextStartDate()
        let lighterWeek = try XCTUnwrap(recoveryBench.day.date)
        XCTAssertEqual(first.stage(now: date), .training)
        XCTAssertEqual(first.stage(now: lighterWeek), .deload)
        XCTAssertThrowsError(try SeedData.startCycle(.strength, starts: transition, context: context, now: lighterWeek))

        try WorkoutSession.start(finalBench.day, context: context)
        for _ in 0..<finalBench.sets {
            try WorkoutLogging.saveSet(exercise: finalBench, kilograms: 40, reps: 10, rir: 3,
                barbellIncrement: 2.5, dumbbellIncrement: 2, context: context)
        }
        XCTAssertEqual(recoveryBench.targetWeight, 34)
        XCTAssertThrowsError(try SeedData.startCycle(.strength, starts: transition, context: context, now: transition))
        try WorkoutSession.finish(finalBench.day, context: context)

        try WorkoutSession.start(recoveryBench.day, context: context)
        for _ in 0..<recoveryBench.sets {
            let next = try WorkoutLogging.saveSet(exercise: recoveryBench, kilograms: 20, reps: 6,
                rir: 4, barbellIncrement: 2.5, dumbbellIncrement: 2, context: context)
            XCTAssertNil(next)
        }
        try WorkoutSession.finish(recoveryBench.day, context: context)
        XCTAssertEqual(first.stage(now: transition), .readyForNextTrack)
        let second = try SeedData.startCycle(.strength, starts: transition, context: context, now: transition)
        XCTAssertTrue(first.isArchived)
        XCTAssertEqual(second.track?.alternate, .hypertrophy)
        XCTAssertEqual(lift("Bench Press", day: 1, week: 1, in: second)?.targetWeight, 36)
        let pastDay = try XCTUnwrap(first.days.first { $0.status == .planned })
        XCTAssertThrowsError(try WorkoutSession.start(pastDay, context: context))

        let backup = try ExportImport.exportJSON(context: context)
        try ExportImport.importJSON(backup, context: context)
        let programs = try context.fetch(FetchDescriptor<Program>())
        XCTAssertEqual(programs.count, 2)
        let archived = try XCTUnwrap(programs.first(where: \.isArchived))
        XCTAssertEqual(archived.track, .hypertrophy)
        XCTAssertEqual(lift("Bench Press", day: 1, week: 12, in: archived)?.logs.count, 4)
        let active = try XCTUnwrap(programs.first { !$0.isArchived })
        XCTAssertEqual(active.track, .strength)
        XCTAssertEqual(lift("Bench Press", day: 1, week: 1, in: active)?.restSeconds, 210)
        XCTAssertEqual(lift("Bench Press", day: 4, week: 1, in: active)?.restSeconds, 210)
    }

    func testLegacyCycleCanAddRecoveryWithoutRewritingTraining() async throws {
        let container = try store()
        let context = container.mainContext
        try await SeedData.seedIfNeeded(context: context, overrideStartDate: date)
        let program = try XCTUnwrap(context.fetch(FetchDescriptor<Program>()).first)
        let after = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 100, to: date))
        try SeedData.addRecoveryToLegacy(program, context: context, now: after)
        XCTAssertEqual(program.days.filter { !$0.isDeload }.count, 48)
        XCTAssertEqual(program.days.filter(\.isDeload).compactMap(\.date).min(), after)
        XCTAssertEqual(program.nextStartDate(), Calendar.current.date(byAdding: .day, value: 7, to: after))
        XCTAssertEqual(program.stage(now: after), .deload)
    }

    func testEndingEarlyPreservesPartialSessionAndRestartsWithFreshTargets() throws {
        let container = try store()
        let context = container.mainContext
        let strength = try SeedData.startCycle(.strength, starts: date, context: context)
        let bench = try XCTUnwrap(lift("Bench Press", day: 1, week: 1, in: strength))
        try WorkoutSession.start(bench.day, context: context, now: date)
        for _ in 0..<bench.sets {
            try WorkoutLogging.saveSet(exercise: bench, kilograms: 90, reps: 5, rir: 2,
                barbellIncrement: 2.5, dumbbellIncrement: 2, context: context)
        }
        let conditioning = try XCTUnwrap(bench.day.conditioning)
        let loggedAt = date.addingTimeInterval(3600)
        try WorkoutSession.recordConditioning(conditioning, minutes: 15, meters: 2000, context: context, now: loggedAt)
        let endedAt = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 45, to: date))
        XCTAssertLessThan(endedAt, strength.nextStartDate())

        try SeedData.endCycleEarly(strength, context: context, now: endedAt)
        XCTAssertTrue(strength.isArchived)
        XCTAssertEqual(bench.day.status, .finished)
        XCTAssertEqual(bench.day.startedAt, date)
        XCTAssertEqual(bench.day.activityDate, loggedAt)
        XCTAssertNil(bench.day.restUntil)
        XCTAssertThrowsError(try SeedData.endCycleEarly(strength, context: context, now: endedAt))

        let backup = try ExportImport.exportJSON(context: context)
        let root = try ExportImport.validatedProgram(backup)
        XCTAssertEqual(root.formatVersion, 5)
        XCTAssertEqual(root.archivedAt, endedAt)
        try ExportImport.importJSON(backup, context: context)
        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<Program>()).first)
        let restoredBench = try XCTUnwrap(lift("Bench Press", day: 1, week: 1, in: restored))
        XCTAssertEqual(restoredBench.logs.count, 3)
        XCTAssertEqual(restoredBench.day.conditioning?.loggedMeters, 2000)
        XCTAssertThrowsError(try SeedData.startCycle(.hypertrophy, starts: date, context: context, now: endedAt))
        let newProgram = try SeedData.startCycle(.hypertrophy, starts: endedAt, context: context, now: endedAt)
        let newBench = try XCTUnwrap(lift("Bench Press", day: 1, week: 1, in: newProgram))
        XCTAssertEqual(newBench.day.date, endedAt)
        XCTAssertEqual(newBench.targetWeight, 50)
        XCTAssertTrue(newBench.logs.isEmpty)
        XCTAssertTrue(restored.isArchived)
    }

    func testReschedulePastAnotherWorkoutOnlyChangesTheSelectedDate() throws {
        let container = try store()
        let context = container.mainContext
        let program = try SeedData.startCycle(.strength, starts: date, context: context)
        let dayTwo = try XCTUnwrap(program.days.first { $0.weekIdx == 1 && $0.dayIdx == 2 })
        let dayFour = try XCTUnwrap(program.days.first { $0.weekIdx == 1 && $0.dayIdx == 4 })
        let dayFourDate = try XCTUnwrap(dayFour.date)
        let originalDates = Dictionary(uniqueKeysWithValues: program.days.map { ($0.persistentModelID, $0.date) })
        let laterDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: dayFourDate))
        let initialTargets = dayTwo.exercises.sorted { $0.orderIdx < $1.orderIdx }.map(\.targetWeight)

        try WorkoutSession.reschedule(dayTwo, to: laterDate, context: context)

        XCTAssertEqual(dayTwo.date, laterDate)
        XCTAssertEqual(dayTwo.dayIdx, 2)
        XCTAssertEqual(dayTwo.weekIdx, 1)
        XCTAssertEqual(dayTwo.exercises.sorted { $0.orderIdx < $1.orderIdx }.map(\.targetWeight), initialTargets)
        for day in program.days where day !== dayTwo {
            XCTAssertEqual(day.date, originalDates[day.persistentModelID] ?? nil)
        }
    }

    private func store() throws -> ModelContainer {
        try ModelContainer(for: Program.self, DayPlan.self, ExerciseTemplate.self, DayExercise.self,
            ExerciseLog.self, ProgressionRule.self, PhaseState.self, Conditioning.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func lift(_ name: String, day: Int, week: Int, in program: Program) -> DayExercise? {
        program.days.first { $0.dayIdx == day && $0.weekIdx == week }?.exercises.first { $0.template.name == name }
    }
}
