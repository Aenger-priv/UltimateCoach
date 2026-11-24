import Foundation

struct CycleDashboardMetrics {
    struct Workouts {
        let finishedWorkouts: Int
        let totalWorkouts: Int
        let scheduledBeforeToday: Int
        let finishedScheduledBeforeToday: Int

        init(program: Program, now: Date = .now, calendar: Calendar = .current) {
            let today = calendar.startOfDay(for: now)
            let due = program.days.filter { $0.date.map { $0 < today } == true }
            finishedWorkouts = program.days.count { $0.status == .finished }
            totalWorkouts = program.days.count
            scheduledBeforeToday = due.count
            finishedScheduledBeforeToday = due.count { $0.status == .finished }
        }
    }

    enum PerformanceMetric {
        case estimatedMax, repsAtSameLoad, loadAtSameReps
    }

    struct Performance {
        let name: String
        let equipment: String
        let metric: PerformanceMetric
        let previousValue: Double
        let latestValue: Double
        /// External load in kilograms for the rep comparison. Nil for unweighted bodyweight work.
        let sharedWeight: Double?
        let sharedReps: Int?
        let previousDate: Date
        let latestDate: Date
    }

    let workouts: Workouts
    let loggedSetsScheduledBeforeToday: Int
    let plannedSetsScheduledBeforeToday: Int
    let performance: Performance?

    init(program: Program, now: Date = .now, calendar: Calendar = .current) {
        workouts = Workouts(program: program, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let dueExercises = program.days.filter { $0.date.map { $0 < today } == true }.flatMap(\.exercises)
        loggedSetsScheduledBeforeToday = dueExercises.reduce(0) { $0 + min($1.logs.count, $1.sets) }
        plannedSetsScheduledBeforeToday = dueExercises.reduce(0) { $0 + $1.sets }
        performance = Self.recentPerformance(in: program)
    }

    private struct Lift: Hashable {
        let name: String
        let equipment: String
        let day: Int
        let order: Int
        let phase: String
        let minReps: Int
        let maxReps: Int

        init(_ exercise: DayExercise) {
            name = exercise.template.name
            equipment = exercise.template.equipment
            day = exercise.day.dayIdx
            order = exercise.orderIdx
            phase = exercise.phase
            minReps = exercise.targetRepsMin
            maxReps = exercise.targetRepsMax
        }
    }

    private static func recentPerformance(in program: Program) -> Performance? {
        // Look at the newest pair for each lift and slot. A changed rep prescription starts a new comparison.
        let finished = program.days.filter { !$0.isDeload && $0.status == .finished }.sorted {
            ($0.finishedAt ?? .distantPast, $0.weekIdx, $0.dayIdx) >
                ($1.finishedAt ?? .distantPast, $1.weekIdx, $1.dayIdx)
        }
        let exercises = finished.flatMap(\.exercises).filter { !$0.logs.isEmpty }
        let byLift = Dictionary(grouping: exercises, by: Lift.init)
        let comparisons = byLift.compactMap { lift, exposures -> (Performance, Int)? in
            guard let latest = exposures.first,
                  let previous = exposures.dropFirst().first(where: { $0.day !== latest.day }),
                  let performance = compare(previous: previous, latest: latest, track: program.track) else { return nil }
            return (performance, lift.order)
        }
        // Prefer an early lift in the workout on ties, without cherry-picking a positive change.
        return comparisons.sorted { left, right in
            if left.0.latestDate != right.0.latestDate { return left.0.latestDate > right.0.latestDate }
            return (left.1, left.0.name, left.0.equipment) < (right.1, right.0.name, right.0.equipment)
        }.first?.0
    }

    private static func compare(previous: DayExercise, latest: DayExercise, track: TrainingTrack?) -> Performance? {
        guard let previousDate = previous.day.finishedAt, let latestDate = latest.day.finishedAt else { return nil }
        let equipment = latest.template.equipment
        let isBodyweight = equipment.lowercased() == "bodyweight"
        let isStrength = track.map { $0 == .strength } ?? (latest.phase == "STR")
        if isStrength && !isBodyweight {
            let metric = ExerciseTrendMetric.estimatedMax
            guard let earlier = previous.logs.compactMap({ metric.value(weight: $0.actualWeight, reps: $0.reps) }).max(),
                  let newer = latest.logs.compactMap({ metric.value(weight: $0.actualWeight, reps: $0.reps) }).max()
            else { return nil }
            return Performance(name: latest.template.name, equipment: equipment, metric: .estimatedMax,
                               previousValue: earlier, latestValue: newer, sharedWeight: nil, sharedReps: nil,
                               previousDate: previousDate, latestDate: latestDate)
        }

        let earlier = setResults(previous.logs, isBodyweight: isBodyweight)
        let newer = setResults(latest.logs, isBodyweight: isBodyweight)
        // Choose the heaviest shared load, independent of the direction of change.
        if let load = newer.repsByLoad.keys.filter({ earlier.repsByLoad[$0] != nil }).max(),
           let previousReps = earlier.repsByLoad[load], let latestReps = newer.repsByLoad[load] {
            return Performance(name: latest.template.name, equipment: equipment, metric: .repsAtSameLoad,
                               previousValue: Double(previousReps), latestValue: Double(latestReps),
                               sharedWeight: load > 0 ? load : nil, sharedReps: nil,
                               previousDate: previousDate, latestDate: latestDate)
        }
        // When the working load changed, compare the heaviest set at the highest shared rep count.
        guard let reps = newer.loadByReps.keys.filter({ earlier.loadByReps[$0] != nil }).max(),
              let previousLoad = earlier.loadByReps[reps], let latestLoad = newer.loadByReps[reps] else { return nil }
        return Performance(name: latest.template.name, equipment: equipment, metric: .loadAtSameReps,
                           previousValue: previousLoad, latestValue: latestLoad, sharedWeight: nil, sharedReps: reps,
                           previousDate: previousDate, latestDate: latestDate)
    }

    private static func setResults(_ logs: [ExerciseLog], isBodyweight: Bool)
        -> (repsByLoad: [Double: Int], loadByReps: [Int: Double]) {
        var repsByLoad: [Double: Int] = [:]
        var loadByReps: [Int: Double] = [:]
        for log in logs where log.reps > 0 {
            let weight = log.actualWeight ?? 0
            guard weight.isFinite, weight >= 0, isBodyweight || weight > 0 else { continue }
            // Stored weights are in kg. Compare at the displayed precision after unit conversion.
            let load = (weight * 10).rounded() / 10
            repsByLoad[load] = max(repsByLoad[load] ?? 0, log.reps)
            loadByReps[log.reps] = max(loadByReps[log.reps] ?? 0, load)
        }
        return (repsByLoad, loadByReps)
    }
}
