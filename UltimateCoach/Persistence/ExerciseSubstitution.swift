import Foundation
import SwiftData

@MainActor
enum ExerciseSubstitution {
    struct Choice: Hashable, Identifiable {
        let name: String
        let equipment: String
        var id: String { name }

        init(_ name: String, _ equipment: String) {
            self.name = name
            self.equipment = equipment
        }

        func matches(_ template: ExerciseTemplate) -> Bool {
            template.name == name && template.equipment == equipment
        }
    }

    private static let families: [[Choice]] = [
        [.init("Bench Press", "barbell"), .init("Flat DB Press", "dumbbell"), .init("Incline DB Press", "dumbbell"),
         .init("Machine Chest Press", "machine"), .init("Push-Up", "bodyweight")],
        [.init("Overhead Press", "barbell"), .init("Seated DB Shoulder Press", "dumbbell"),
         .init("Machine Shoulder Press", "machine")],
        [.init("Barbell Row", "barbell"), .init("One-Arm Row", "dumbbell"),
         .init("Chest-Supported DB Row", "dumbbell"), .init("Seated Cable Row", "cable")],
        [.init("Lat Pulldown", "cable"), .init("Pull-Ups", "bodyweight"), .init("Chin-Ups", "bodyweight")],
        [.init("Back Squat", "barbell"), .init("Bulgarian Split Squat", "dumbbell"),
         .init("Goblet Squat", "dumbbell"), .init("Leg Press", "machine")],
        [.init("Deadlift", "barbell"), .init("Romanian Deadlift", "barbell"), .init("DB Romanian Deadlift", "dumbbell")],
        [.init("Leg Curl", "machine"), .init("Lying Leg Curl", "machine"), .init("Seated Leg Curl", "machine")],
        [.init("Standing Calf Raise", "machine"), .init("Seated Calf Raise", "machine"), .init("DB Calf Raise", "dumbbell")],
        [.init("Lateral Raise", "dumbbell"), .init("Cable Lateral Raise", "cable")],
        [.init("DB Curl", "dumbbell"), .init("Hammer Curl", "dumbbell"),
         .init("Incline DB Curl", "dumbbell"), .init("Cable Curl", "cable")],
        [.init("Cable Triceps Pushdown", "cable"), .init("Dips", "bodyweight"), .init("Overhead Triceps Extension", "dumbbell")],
    ]

    static func choices(for exercise: DayExercise) -> [Choice] {
        guard isEligible(exercise), let family = families.first(where: {
            $0.contains { $0.matches(exercise.template) }
        }) else { return [] }
        return family.filter { choice in
            !exercise.day.exercises.contains { choice.matches($0.template) }
        }
    }

    enum SwapError: LocalizedError {
        case unavailable, invalidWeight, alreadyInFutureWorkout

        var errorDescription: String? {
            switch self {
            case .unavailable: "You can swap this exercise before logging its first set."
            case .invalidWeight: "Enter a starting weight between 0 and 500 kg, or the equivalent in pounds."
            case .alreadyInFutureWorkout: "This exercise is already in a future workout. Try swapping this workout only."
            }
        }
    }

    static func swap(_ exercise: DayExercise, to choice: Choice, weight: Double?, includeUpcoming: Bool,
                     context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws {
        guard choices(for: exercise).contains(choice) else { throw SwapError.unavailable }
        guard choice.equipment == "bodyweight" ? weight == nil :
                weight.map({ $0.isFinite && (0...500.001).contains($0) }) == true else { throw SwapError.invalidWeight }
        let day = exercise.day
        let program = day.program
        let template = exercise.template
        let anchor = max(day.date ?? .distantPast, calendar.startOfDay(for: now))
        let upcoming = includeUpcoming ? program.days.filter {
            $0.dayIdx == day.dayIdx && $0.weekIdx > day.weekIdx && $0.status == .planned &&
                ($0.date ?? .distantPast) >= anchor
        }.flatMap(\.exercises).filter {
            $0.orderIdx == exercise.orderIdx && $0.template === template && $0.logs.isEmpty
        } : []
        guard !upcoming.contains(where: { future in future.day.exercises.contains { choice.matches($0.template) } }) else {
            throw SwapError.alreadyInFutureWorkout
        }
        let alternative = program.days.lazy.flatMap(\.exercises).map(\.template).first { choice.matches($0) }
            ?? ExerciseTemplate(name: choice.name, muscleGroup: template.muscleGroup, equipment: choice.equipment,
                                defaultSets: template.defaultSets, repMin: template.repMin, repMax: template.repMax,
                                restSec: template.restSec)
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        do {
            if alternative.modelContext == nil { context.insert(alternative) }
            for item in [exercise] + upcoming {
                item.plannedRestSeconds = item.restSeconds
                item.template = alternative
                item.targetWeight = item.day.isDeload ? TrainingCycle.recoveryLoad(from: weight) : weight
                item.manualTarget = nil
                item.targetNote = nil
            }
            // The entered value reflects the load for the workout currently being edited.
            exercise.targetWeight = weight
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func isEligible(_ exercise: DayExercise) -> Bool {
        !exercise.day.program.isArchived && exercise.logs.isEmpty &&
            (exercise.day.status == .planned || exercise.day.status == .inProgress)
    }
}
