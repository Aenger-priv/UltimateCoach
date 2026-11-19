import Foundation
import SwiftData

@MainActor
enum WorkoutLogging {
    enum LoggingError: LocalizedError {
        case completed, invalidValues, closedWorkout, cannotUndo

        var errorDescription: String? {
            switch self {
            case .closedWorkout: "Start or resume this workout before logging a set."
            case .completed: "All planned sets have already been saved."
            case .invalidValues: "Enter a valid weight, rep count, and reps in reserve."
            case .cannotUndo: "This set can no longer be undone. You can edit it in Saved sets."
            }
        }
    }

    struct SavedSet {
        let log: ExerciseLog
        let nextTarget: Target?
        fileprivate let previousRest: Date?
        fileprivate let targets: [TargetChange]
    }

    fileprivate struct TargetChange {
        let exercise: DayExercise
        let before: TargetSnapshot
        let after: TargetSnapshot
    }

    fileprivate struct TargetSnapshot: Equatable {
        let weight: Double?
        let repMin: Int
        let repMax: Int
        let note: String?
        let templateID: PersistentIdentifier

        init(_ exercise: DayExercise) {
            weight = exercise.targetWeight
            repMin = exercise.targetRepsMin
            repMax = exercise.targetRepsMax
            note = exercise.targetNote
            templateID = exercise.template.persistentModelID
        }

        func restore(to exercise: DayExercise) {
            exercise.targetWeight = weight
            exercise.targetRepsMin = repMin
            exercise.targetRepsMax = repMax
            exercise.targetNote = note
        }
    }

    @discardableResult
    static func saveSet(exercise: DayExercise, kilograms: Double, reps: Int, rir: Double?,
                        barbellIncrement: Double, dumbbellIncrement: Double, context: ModelContext) throws -> Target? {
        try logSet(exercise: exercise, kilograms: kilograms, reps: reps, rir: rir,
                   barbellIncrement: barbellIncrement, dumbbellIncrement: dumbbellIncrement, context: context).nextTarget
    }

    static func logSet(exercise: DayExercise, kilograms: Double, reps: Int, rir: Double?,
                       barbellIncrement: Double, dumbbellIncrement: Double, context: ModelContext) throws -> SavedSet {
        guard exercise.day.status == .inProgress else { throw LoggingError.closedWorkout }
        guard exercise.logs.count < exercise.sets else { throw LoggingError.completed }
        try validate(kilograms: kilograms, reps: reps, rir: rir)
        return try transaction(context) {
            let previousRest = exercise.day.restUntil
            let index = (exercise.logs.map(\.setIdx).max() ?? 0) + 1
            let log = ExerciseLog(dayExercise: exercise, setIdx: index, actualWeight: kilograms, reps: reps, rir: rir)
            context.insert(log)
            if !exercise.logs.contains(where: { $0 === log }) { exercise.logs.append(log) }
            exercise.day.restUntil = log.timestamp.addingTimeInterval(Double(max(0, exercise.restSeconds)))
            var before: [(DayExercise, TargetSnapshot)] = []
            let next = try updateTarget(exercise, barbellIncrement: barbellIncrement, dumbbellIncrement: dumbbellIncrement) {
                before.append(($0, TargetSnapshot($0)))
            }
            let targets = before.map { TargetChange(exercise: $0.0, before: $0.1, after: TargetSnapshot($0.0)) }
            return SavedSet(log: log, nextTarget: next, previousRest: previousRest, targets: targets)
        }
    }

    static func undo(_ saved: SavedSet, context: ModelContext, now: Date = .now) throws {
        guard saved.log.modelContext === context else { throw LoggingError.cannotUndo }
        let exercise = saved.log.dayExercise
        let day = exercise.day
        guard day.status == .inProgress, !day.program.isArchived,
              day.exercises.flatMap(\.logs).max(by: { $0.timestamp < $1.timestamp }) === saved.log,
              saved.targets.allSatisfy({
                  $0.exercise.day.status == .planned && $0.exercise.manualTarget != true &&
                      TargetSnapshot($0.exercise) == $0.after
              }) else { throw LoggingError.cannotUndo }
        try transaction(context) {
            for target in saved.targets { target.before.restore(to: target.exercise) }
            exercise.logs.removeAll { $0 === saved.log }
            context.delete(saved.log)
            day.restUntil = saved.previousRest.flatMap { $0 > now ? $0 : nil }
        }
    }

    static func previousSet(for exercise: DayExercise, context: ModelContext) throws -> ExerciseLog? {
        let name = exercise.template.name
        let equipment = exercise.template.equipment
        let matching = FetchDescriptor<DayExercise>(predicate: #Predicate {
            $0.template.name == name && $0.template.equipment == equipment
        })
        return try context.fetch(matching).lazy
            .filter { $0.day !== exercise.day && !$0.day.isDeload && $0.day.status == .finished }
            .flatMap(\.logs)
            .max { $0.timestamp < $1.timestamp }
    }

    static func changedTargets(after day: DayPlan) -> [DayExercise] {
        guard !day.program.isArchived, !day.isDeload else { return [] }
        return day.exercises.sorted { $0.orderIdx < $1.orderIdx }.compactMap { exercise in
            guard exercise.logs.count == exercise.sets,
                  let next = futureExposures(after: exercise).first(where: { !$0.day.isDeload }),
                  next.day.status == .planned, next.manualTarget != true,
                  (next.day.date ?? .distantFuture) >= (day.date ?? .distantPast),
                  next.targetNote?.hasPrefix("Load ") == true,
                  next.targetWeight != exercise.targetWeight else { return nil }
            return next
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

    private static func transaction<Result>(_ context: ModelContext, changes: () throws -> Result) throws -> Result {
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

    private static func exposures(for exercise: DayExercise) -> [DayExercise] {
        exercise.day.program.days.filter { $0.dayIdx == exercise.day.dayIdx && $0.status != .skipped }
            .flatMap(\.exercises).filter { $0.template === exercise.template && $0.orderIdx == exercise.orderIdx }
            .sorted { $0.day.weekIdx < $1.day.weekIdx }
    }

    private static func futureExposures(after exercise: DayExercise) -> [DayExercise] {
        exposures(for: exercise).filter { $0.day.weekIdx > exercise.day.weekIdx }
    }

    private static func updateTarget(_ exercise: DayExercise, barbellIncrement: Double,
                                     dumbbellIncrement: Double,
                                     willChange: (DayExercise) -> Void = { _ in }) throws -> Target? {
        guard exercise.logs.count == exercise.sets, !exercise.day.isDeload, !exercise.day.program.isArchived else {
            return nil
        }
        let exposures = exposures(for: exercise)
        let later = exposures.filter { $0.day.weekIdx > exercise.day.weekIdx }
        updateRecoveryTarget(after: exercise, later: later, willChange: willChange)
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
        willChange(future)
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

    private static func updateRecoveryTarget(after exercise: DayExercise, later: [DayExercise],
                                             willChange: (DayExercise) -> Void) {
        guard let recovery = later.first(where: { $0.day.isDeload }), recovery.day.status == .planned,
              recovery.logs.isEmpty, recovery.manualTarget != true,
              !later.contains(where: { !$0.day.isDeload && !$0.logs.isEmpty }),
              let planned = exercise.targetWeight else { return }
        let performed = exercise.logs.compactMap(\.actualWeight).min() ?? planned
        willChange(recovery)
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
