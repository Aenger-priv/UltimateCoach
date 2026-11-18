import Foundation
import SwiftData

@MainActor
enum WorkoutLogging {
    enum LoggingError: LocalizedError {
        case completed, invalidValues, closedWorkout

        var errorDescription: String? {
            switch self {
            case .closedWorkout: "Start or resume this workout before logging a set."
            case .completed: "All planned sets have already been saved."
            case .invalidValues: "Enter a valid weight, rep count, and reps in reserve."
            }
        }
    }

    @discardableResult
    static func saveSet(exercise: DayExercise, kilograms: Double, reps: Int, rir: Double?,
                        barbellIncrement: Double, dumbbellIncrement: Double, context: ModelContext) throws -> Target? {
        guard exercise.day.status == .inProgress else { throw LoggingError.closedWorkout }
        guard exercise.logs.count < exercise.sets else { throw LoggingError.completed }
        try validate(kilograms: kilograms, reps: reps, rir: rir)
        return try transaction(context) {
            let index = (exercise.logs.map(\.setIdx).max() ?? 0) + 1
            let log = ExerciseLog(dayExercise: exercise, setIdx: index, actualWeight: kilograms, reps: reps, rir: rir)
            context.insert(log)
            if !exercise.logs.contains(where: { $0 === log }) { exercise.logs.append(log) }
            exercise.day.restUntil = log.timestamp.addingTimeInterval(Double(max(0, exercise.restSeconds)))
            return try updateTarget(exercise, barbellIncrement: barbellIncrement, dumbbellIncrement: dumbbellIncrement)
        }
    }

    @discardableResult
    static func editSet(_ log: ExerciseLog, kilograms: Double, reps: Int, rir: Double?,
                        barbellIncrement: Double, dumbbellIncrement: Double, context: ModelContext) throws -> Target? {
        try validate(kilograms: kilograms, reps: reps, rir: rir)
        return try transaction(context) {
            log.actualWeight = kilograms
            log.reps = reps
            log.rir = rir
            return try updateTarget(log.dayExercise, barbellIncrement: barbellIncrement, dumbbellIncrement: dumbbellIncrement)
        }
    }

    private static func validate(kilograms: Double, reps: Int, rir: Double?) throws {
        guard kilograms.isFinite, (0...500.001).contains(kilograms), (1...100).contains(reps),
              rir.map({ $0.isFinite && (0...6).contains($0) }) ?? true else { throw LoggingError.invalidValues }
    }

    private static func transaction(_ context: ModelContext, changes: () throws -> Target?) throws -> Target? {
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        do {
            let target = try changes()
            try context.save()
            return target
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func updateTarget(_ exercise: DayExercise, barbellIncrement: Double,
                                     dumbbellIncrement: Double) throws -> Target? {
        guard exercise.logs.count == exercise.sets, !exercise.day.isDeload, !exercise.day.program.isArchived else {
            return nil
        }
        let exposures = exercise.day.program.days.filter { $0.dayIdx == exercise.day.dayIdx && $0.status != .skipped }
            .flatMap(\.exercises).filter { $0.template === exercise.template }
            .sorted { $0.day.weekIdx < $1.day.weekIdx }
        let later = exposures.filter { $0.day.weekIdx > exercise.day.weekIdx }
        updateRecoveryTarget(after: exercise, later: later)
        let training = later.filter { !$0.day.isDeload }
        // Editing a past set never rewrites a target once a later exposure has started.
        guard let future = training.first, future.day.status == .planned, future.logs.isEmpty, future.manualTarget != true,
              training.allSatisfy({ $0.day.status == .planned && $0.logs.isEmpty }),
              (future.day.date ?? .distantFuture) >= (exercise.day.date ?? .distantPast) else { return nil }
        var misses = 0
        for exposure in exposures.reversed() where exposure.day.weekIdx < exercise.day.weekIdx {
            guard exposure.logs.count == exposure.sets else { break }
            guard let target = exposure.targetWeight,
                  exposure.logs.allSatisfy({ ($0.actualWeight ?? 0) + 0.005 >= target }),
                  exposure.logs.contains(where: { $0.reps < exposure.targetRepsMin }) else { break }
            misses += 1
        }
        let defaults = try RuleDefaults.load()
        let computed = computeNextTargets(
            lastLogs: exercise.logs.map { SetLog(weight: $0.actualWeight, reps: $0.reps, rir: $0.rir) },
            lastTarget: Target(weight: exercise.targetWeight, repMin: exercise.targetRepsMin,
                               repMax: exercise.targetRepsMax, sets: exercise.sets, phase: exercise.phase),
            rule: Rule(equipment: exercise.template.equipment, barbellInc: barbellIncrement,
                       dbInc: dumbbellIncrement, deloadPct: defaults.deloadPct, missLimit: defaults.missLimit),
            phase: exercise.phase, consecutiveMisses: misses, blockStartLoad: nil,
            minimumReserve: exercise.day.program.track == nil ? nil : 2
        )
        if (computed.weight ?? 0) > (exercise.targetWeight ?? 0) {
            future.targetNote = "Load increased after you reached the top of the rep range on every set."
        } else if (computed.weight ?? 0) < (exercise.targetWeight ?? 0) {
            future.targetNote = "Load reduced after repeated missed targets."
        } else {
            future.targetNote = "Repeating the previous target."
        }
        future.targetWeight = computed.weight
        future.targetRepsMin = computed.repMin
        future.targetRepsMax = computed.repMax
        return computed
    }

    private static func updateRecoveryTarget(after exercise: DayExercise, later: [DayExercise]) {
        guard let recovery = later.first(where: { $0.day.isDeload }), recovery.day.status == .planned,
              recovery.logs.isEmpty, recovery.manualTarget != true,
              !later.contains(where: { !$0.day.isDeload && !$0.logs.isEmpty }),
              let planned = exercise.targetWeight else { return }
        let performed = exercise.logs.compactMap(\.actualWeight).min() ?? planned
        recovery.targetWeight = TrainingCycle.recoveryLoad(from: min(planned, performed))
    }

    private struct RuleDefaults: Decodable {
        let deloadPct: Double
        let missLimit: Int

        private struct Document: Decodable { let defaults: RuleDefaults }

        static func load() throws -> RuleDefaults {
            guard let url = Bundle.main.url(forResource: "progression_rules", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try JSONDecoder().decode(Document.self, from: Data(contentsOf: url)).defaults
        }
    }
}
