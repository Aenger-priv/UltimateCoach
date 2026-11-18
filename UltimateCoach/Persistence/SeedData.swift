import Foundation
import SwiftData

@MainActor
enum SeedData {
    struct SeedConfig: Decodable {
        let programName: String
        let totalWeeks: Int
        let dayTemplates: [DayTemplate]
    }

    struct DayTemplate: Decodable {
        let dayIdx: Int
        let exercises: [ExerciseSpec]
        let conditioning: ConditioningSpec?
    }

    struct ExerciseSpec: Decodable {
        let name: String
        let muscleGroup: String
        let equipment: String
        let sets: Int
        let repMin: Int
        let repMax: Int
        let restSec: Int
        let tempo: String?
        let targetWeight: Double?
    }

    struct ConditioningSpec: Decodable {
        let type: String
        let protocolText: String
        let targetZone: String?
        let targetPace: String?
        let durationMin: Int?
    }

    enum CycleError: LocalizedError {
        case cycleInProgress, startDateTooEarly, alreadyArchived

        var errorDescription: String? {
            switch self {
            case .cycleInProgress: "Finish the current cycle and any active workout first."
            case .startDateTooEarly: "Choose a start date after your current cycle."
            case .alreadyArchived: "This program has already ended."
            }
        }
    }

    // Retained for testing the original 12-week template and reading existing installs.
    static func seedIfNeeded(context: ModelContext, overrideStartDate: Date? = nil) async throws {
        guard try context.fetchCount(FetchDescriptor<Program>()) == 0 else { return }
        let config = try load("program_seed")
        _ = try save(context) {
            makeProgram(config, track: nil, starts: overrideStartDate ?? .now, previous: nil, context: context)
        }
    }

    @discardableResult
    static func startCycle(_ track: TrainingTrack, starts: Date, context: ModelContext,
                           now: Date = .now, calendar: Calendar = .current) throws -> Program {
        let programs = try context.fetch(FetchDescriptor<Program>())
        let previous = programs.first { !$0.isArchived }
        let start = calendar.startOfDay(for: starts)
        if let previous {
            guard previous.stage(now: now, calendar: calendar) == .readyForNextTrack else {
                throw CycleError.cycleInProgress
            }
            guard start >= previous.nextStartDate(calendar: calendar) else { throw CycleError.startDateTooEarly }
        } else if let endedAt = Program.latestArchived(in: programs)?.archivedAt,
                  start < calendar.startOfDay(for: endedAt) {
            throw CycleError.startDateTooEarly
        }
        let config = try load(track == .hypertrophy ? "hypertrophy_seed" : "strength_seed")
        return try save(context) {
            previous?.archivedAt = now
            return makeProgram(config, track: track, starts: start, previous: previous, context: context, calendar: calendar)
        }
    }

    static func endCycleEarly(_ program: Program, context: ModelContext, now: Date = .now) throws {
        guard !program.isArchived else { throw CycleError.alreadyArchived }
        try save(context) {
            for day in program.days where day.status == .inProgress {
                if day.hasResults {
                    // Date the partial session by the work performed, even if the program ends weeks later.
                    day.finishedAt = day.activityDate ?? day.startedAt ?? now
                } else {
                    day.startedAt = nil
                }
                day.restUntil = nil
            }
            program.archivedAt = now
        }
    }

    static func addRecoveryToLegacy(_ program: Program, context: ModelContext, now: Date = .now,
                                    calendar: Calendar = .current) throws {
        guard !program.isArchived, program.deloadWeek == nil,
              program.stage(now: now, calendar: calendar) == .readyForNextTrack else {
            throw CycleError.cycleInProgress
        }
        let anchor = calendar.startOfDay(for: now)
        try save(context) {
            addRecoveryWeek(to: program, anchor: anchor, context: context, calendar: calendar)
        }
    }

    private static func load(_ resource: String) throws -> SeedConfig {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let config = try JSONDecoder().decode(SeedConfig.self, from: Data(contentsOf: url))
        guard config.totalWeeks > 0, !config.dayTemplates.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        return config
    }

    @discardableResult
    private static func makeProgram(_ config: SeedConfig, track: TrainingTrack?, starts: Date, previous: Program?,
                                    context: ModelContext, calendar: Calendar = .current) -> Program {
        let start = calendar.startOfDay(for: starts)
        let program = Program(name: config.programName, startDate: start, totalWeeks: config.totalWeeks)
        program.trackCode = track?.rawValue
        context.insert(program)
        var templates: [String: ExerciseTemplate] = [:]
        let recent = recentWeights(in: previous)

        for week in 1...config.totalWeeks {
            for spec in config.dayTemplates.sorted(by: { $0.dayIdx < $1.dayIdx }) {
                let date = computeDate(start: start, weekIdx: week, dayIdx: spec.dayIdx, calendar: calendar)
                let day = makeDay(program, week: week, slot: spec.dayIdx, date: date, context: context)
                for (index, ex) in spec.exercises.enumerated() {
                    let template = templates[ex.name] ?? ExerciseTemplate(
                        name: ex.name, muscleGroup: ex.muscleGroup, equipment: ex.equipment,
                        defaultSets: ex.sets, repMin: ex.repMin, repMax: ex.repMax,
                        restSec: ex.restSec, tempo: ex.tempo
                    )
                    if templates[ex.name] == nil {
                        context.insert(template)
                        templates[ex.name] = template
                    }
                    let priorWeight = recent[ExerciseKey(name: ex.name, equipment: ex.equipment)]
                    let carryover = priorWeight.map { previous in
                        TrainingCycle.startingLoad(previousWeight: previous.weight, previousReps: previous.reps, targetReps: ex.repMin)
                    }
                    let exercise = DayExercise(day: day, template: template, targetWeight: carryover ?? ex.targetWeight,
                        targetRepsMin: ex.repMin, targetRepsMax: ex.repMax, sets: ex.sets,
                        orderIdx: index, phase: track?.phase ?? "HYP")
                    if track != nil { exercise.plannedRestSeconds = ex.restSec }
                    if week == 1, carryover != nil {
                        exercise.targetNote = "Starts lighter than your last completed workout with this lift. Adjust as needed."
                    }
                    insert(exercise, into: day, context: context)
                }
                if let c = spec.conditioning {
                    let conditioning = Conditioning(day: day, type: c.type, protocolText: c.protocolText,
                        targetZone: c.targetZone, targetPace: c.targetPace, durationMin: c.durationMin)
                    context.insert(conditioning)
                    day.conditioning = conditioning
                }
            }
        }
        if track != nil { addRecoveryWeek(to: program, anchor: nil, context: context, calendar: calendar) }
        return program
    }

    private static func addRecoveryWeek(to program: Program, anchor: Date?, context: ModelContext, calendar: Calendar) {
        let finalWeek = program.totalWeeks
        let week = finalWeek + 1
        let start = anchor ?? computeDate(start: program.startDate, weekIdx: week, dayIdx: 1, calendar: calendar)
        program.totalWeeks = week
        program.deloadWeek = week
        let finalDays = program.days.filter { $0.weekIdx == finalWeek }
        for final in finalDays {
            let date = computeDate(start: start, weekIdx: 1, dayIdx: final.dayIdx, calendar: calendar)
            let day = makeDay(program, week: week, slot: final.dayIdx, date: date, context: context)
            for source in final.exercises {
                let completed = source.logs.count == source.sets ? source.logs.compactMap(\.actualWeight).min() : nil
                let reference = source.targetWeight.map { min($0, completed ?? $0) }
                let exercise = DayExercise(day: day, template: source.template, targetWeight: TrainingCycle.recoveryLoad(from: reference),
                    targetRepsMin: source.targetRepsMin, targetRepsMax: source.targetRepsMin,
                    sets: TrainingCycle.recoverySets(from: source.sets), orderIdx: source.orderIdx, phase: source.phase)
                exercise.plannedRestSeconds = source.plannedRestSeconds
                insert(exercise, into: day, context: context)
            }
        }
    }

    private static func makeDay(_ program: Program, week: Int, slot: Int, date: Date, context: ModelContext) -> DayPlan {
        let day = DayPlan(program: program, weekIdx: week, dayIdx: slot)
        day.date = date
        context.insert(day)
        program.days.append(day)
        return day
    }

    private static func insert(_ exercise: DayExercise, into day: DayPlan, context: ModelContext) {
        context.insert(exercise)
        day.exercises.append(exercise)
    }

    private struct ExerciseKey: Hashable {
        var name: String
        var equipment: String
    }

    private struct PreviousSet {
        let date: Date
        let weight: Double
        let reps: Int
    }

    private static func recentWeights(in program: Program?) -> [ExerciseKey: PreviousSet] {
        var mostRecent: [ExerciseKey: PreviousSet] = [:]
        for day in program?.days ?? [] where !day.isDeload {
            for exercise in day.exercises where exercise.logs.count == exercise.sets && exercise.template.equipment != "bodyweight" {
                guard let weight = exercise.logs.compactMap(\.actualWeight).min(), weight > 0,
                      let reps = exercise.logs.map(\.reps).min(),
                      let date = exercise.logs.map(\.timestamp).max() else { continue }
                let key = ExerciseKey(name: exercise.template.name, equipment: exercise.template.equipment)
                if let existing = mostRecent[key],
                   date < existing.date || (date == existing.date && (weight, reps) >= (existing.weight, existing.reps)) { continue }
                mostRecent[key] = PreviousSet(date: date, weight: weight, reps: reps)
            }
        }
        return mostRecent
    }

    private static func save<T>(_ context: ModelContext, changes: () -> T) throws -> T {
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        do {
            let value = changes()
            try context.save()
            return value
        } catch {
            context.rollback()
            throw error
        }
    }

    static func computeDate(start: Date, weekIdx: Int, dayIdx: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: (weekIdx - 1) * 7 + max(0, dayIdx - 1), to: start) ?? start
    }
}
