import XCTest
import SwiftData
@testable import UltimateCoach

@MainActor
final class FoundationTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Program.self, DayPlan.self, ExerciseTemplate.self, DayExercise.self,
            ExerciseLog.self, ProgressionRule.self, PhaseState.self, Conditioning.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testPoundsRoundTripPreservesKilograms() {
        let displayed = WeightUnit.display(60, useKilograms: false)
        XCTAssertEqual(displayed, 132.277, accuracy: 0.001)
        XCTAssertEqual(WeightUnit.kilograms(displayed, useKilograms: false), 60, accuracy: 0.00001)
    }

    func testIncompleteOrLighterWorkDoesNotIncreaseTarget() {
        let target = Target(weight: 60, repMin: 8, repMax: 12, sets: 3, phase: "HYP")
        let rule = Rule(equipment: "barbell", barbellInc: 2.5, dbInc: 2, deloadPct: 0.1, missLimit: 3)
        for logs in [[], [SetLog(weight: 60, reps: 12, rir: 2)], Array(repeating: SetLog(weight: 20, reps: 12, rir: 2), count: 3)] {
            XCTAssertEqual(computeNextTargets(lastLogs: logs, lastTarget: target, rule: rule,
                phase: "HYP", consecutiveMisses: 0, blockStartLoad: nil), target)
        }
    }

    func testFailedRowingDoesNotProgress() {
        XCTAssertEqual(nextRowingPrescription(previous: "Zone2 26-30m", success: false), "Zone2 26-30m")
    }

    func testSeedIsIdempotentAndUsesSelectedStartDate() async throws {
        let store = try container()
        let date = Calendar.current.startOfDay(for: Date())
        try await SeedData.seedIfNeeded(context: store.mainContext, overrideStartDate: date)
        try await SeedData.seedIfNeeded(context: store.mainContext, overrideStartDate: .distantPast)
        let programs = try store.mainContext.fetch(FetchDescriptor<Program>())
        XCTAssertEqual(programs.count, 1)
        XCTAssertEqual(programs[0].startDate, date)
        XCTAssertEqual(programs[0].days.count, 48)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<DayExercise>()), 228)
    }

    func testLoggingUpdatesCorrectDayAndPreventsExtraSets() async throws {
        let store = try container()
        let context = store.mainContext
        try await SeedData.seedIfNeeded(context: context)
        let days = try context.fetch(FetchDescriptor<DayPlan>())
        let day = try XCTUnwrap(days.first { $0.weekIdx == 1 && $0.dayIdx == 2 })
        let squat = try XCTUnwrap(day.exercises.first { $0.template.name == "Back Squat" })
        let nextDay = try XCTUnwrap(days.first { $0.weekIdx == 2 && $0.dayIdx == 2 })
        let nextSquat = try XCTUnwrap(nextDay.exercises.first { $0.template === squat.template })
        try WorkoutSession.start(day, context: context)
        for index in 0..<squat.sets {
            let next = try WorkoutLogging.saveSet(exercise: squat, kilograms: 80, reps: 10, rir: 2,
                barbellIncrement: 2.5, dumbbellIncrement: 2, context: context)
            if index < squat.sets - 1 { XCTAssertNil(next) }
        }
        XCTAssertEqual(squat.logs.count, 4)
        XCTAssertEqual(nextSquat.targetWeight, 82.5)
        XCTAssertThrowsError(try WorkoutLogging.saveSet(exercise: squat, kilograms: 80, reps: 10, rir: 2,
            barbellIncrement: 2.5, dumbbellIncrement: 2, context: context))
        XCTAssertEqual(squat.logs.count, 4)
    }

    func testBackupRoundTripPreservesGraphAndInvalidImportPreservesData() async throws {
        let store = try container()
        let context = store.mainContext
        try await SeedData.seedIfNeeded(context: context)
        let exercise = try XCTUnwrap(context.fetch(FetchDescriptor<DayExercise>()).first)
        try WorkoutSession.start(exercise.day, context: context)
        let cardio = try XCTUnwrap(exercise.day.conditioning)
        try WorkoutSession.recordConditioning(cardio, minutes: 18, meters: 3500, context: context)
        try WorkoutLogging.saveSet(exercise: exercise, kilograms: 20, reps: 8, rir: 2,
            barbellIncrement: 2.5, dumbbellIncrement: 2, context: context)
        try WorkoutSession.finish(exercise.day, context: context)
        let data = try ExportImport.exportJSON(context: context)
        XCTAssertThrowsError(try ExportImport.importJSON(Data("{}".utf8), context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseLog>()), 1)
        try ExportImport.importJSON(data, context: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Program>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DayPlan>()), 48)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DayExercise>()), 228)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseLog>()), 1)
        let restoredDay = try XCTUnwrap(context.fetch(FetchDescriptor<DayPlan>()).first { $0.status == .finished })
        XCTAssertEqual(restoredDay.conditioning?.loggedMinutes, 18)
        XCTAssertEqual(restoredDay.conditioning?.loggedMeters, 3500)
        let restored = try ExportImport.exportJSON(context: context)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: restored) as? NSDictionary,
                       try JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    func testLegacyBackupImportsAndFutureVersionDoesNotReplaceData() async throws {
        let store = try container()
        let context = store.mainContext
        try await SeedData.seedIfNeeded(context: context)
        let data = try ExportImport.exportJSON(context: context)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "formatVersion")
        try ExportImport.importJSON(JSONSerialization.data(withJSONObject: json), context: context)
        json["formatVersion"] = 999
        XCTAssertThrowsError(try ExportImport.importJSON(JSONSerialization.data(withJSONObject: json), context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DayPlan>()), 48)
    }

    func testSessionRulesProtectActiveAndLoggedWorkouts() async throws {
        let store = try container()
        let context = store.mainContext
        try await SeedData.seedIfNeeded(context: context)
        let days = try context.fetch(FetchDescriptor<DayPlan>(sortBy: [SortDescriptor(\.date)]))
        let first = try XCTUnwrap(days.first)
        let second = try XCTUnwrap(days.dropFirst().first)
        let date = try XCTUnwrap(first.date)
        let secondDate = try XCTUnwrap(second.date)
        XCTAssertThrowsError(try WorkoutSession.reschedule(second, to: date, context: context))
        XCTAssertEqual(second.date, secondDate)
        try WorkoutSession.start(first, context: context)
        XCTAssertThrowsError(try WorkoutSession.start(second, context: context))
        XCTAssertThrowsError(try WorkoutSession.finish(first, context: context))
        let cardio = try XCTUnwrap(first.conditioning)
        try WorkoutSession.recordConditioning(cardio, minutes: 10, meters: nil, context: context)
        XCTAssertThrowsError(try WorkoutSession.skip(first, context: context))
        try WorkoutSession.finish(first, context: context)
        XCTAssertEqual(first.status, .finished)
        try WorkoutSession.skip(second, context: context)
        XCTAssertEqual(second.status, .skipped)
    }

    func testManualTargetSurvivesProgressionAndBackup() async throws {
        let store = try container()
        let context = store.mainContext
        try await SeedData.seedIfNeeded(context: context)
        let exercises = try context.fetch(FetchDescriptor<DayExercise>())
        let first = try XCTUnwrap(exercises.first { $0.day.weekIdx == 1 && $0.template.name == "Bench Press" })
        let next = try XCTUnwrap(exercises.first { $0.day.weekIdx == 2 && $0.template === first.template })
        try WorkoutSession.setPlannedLoad(next, kilograms: 55, context: context)
        try WorkoutSession.start(first.day, context: context)
        for _ in 0..<first.sets {
            try WorkoutLogging.saveSet(exercise: first, kilograms: 60, reps: 12, rir: nil,
                barbellIncrement: 2.5, dumbbellIncrement: 2, context: context)
        }
        XCTAssertEqual(next.targetWeight, 55)
        let data = try ExportImport.exportJSON(context: context)
        try ExportImport.importJSON(data, context: context)
        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<DayExercise>()).first { $0.manualTarget == true })
        XCTAssertEqual(restored.targetWeight, 55)
        XCTAssertEqual(restored.targetNote, "You set this target.")
    }

    func testEditingCompletedSetRecalculatesUnstartedTarget() async throws {
        let store = try container()
        let context = store.mainContext
        try await SeedData.seedIfNeeded(context: context)
        let exercises = try context.fetch(FetchDescriptor<DayExercise>())
        let first = try XCTUnwrap(exercises.first { $0.day.weekIdx == 1 && $0.template.name == "Bench Press" })
        let next = try XCTUnwrap(exercises.first { $0.day.weekIdx == 2 && $0.template === first.template })
        try WorkoutSession.start(first.day, context: context)
        for _ in 0..<first.sets {
            try WorkoutLogging.saveSet(exercise: first, kilograms: 60, reps: 12, rir: 2,
                barbellIncrement: 2.5, dumbbellIncrement: 2, context: context)
        }
        XCTAssertEqual(next.targetWeight, 62.5)
        try WorkoutSession.finish(first.day, context: context)
        let log = try XCTUnwrap(first.logs.first)
        let timestamp = log.timestamp
        try WorkoutLogging.editSet(log, kilograms: 60, reps: 8, rir: 2, barbellIncrement: 2.5,
            dumbbellIncrement: 2, context: context)
        XCTAssertEqual(next.targetWeight, 60)
        XCTAssertEqual(log.timestamp, timestamp)
    }
}
