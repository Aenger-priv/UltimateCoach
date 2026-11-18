import Foundation
import SwiftData

// Lightweight export/import using DTOs to avoid SwiftData graph encoding.
struct ExportImport {
    struct ExportProgram: Codable {
        var formatVersion: Int? = 4
        let name: String
        let startDate: Date
        let totalWeeks: Int
        let days: [ExportDay]
        var rules: [ExportRule]? = nil
        var phases: [ExportPhase]? = nil
        var trackCode: String? = nil
        var deloadWeek: Int? = nil
        var archivedAt: Date? = nil
        var archivedCycles: [ExportProgram]? = nil
    }
    struct ExportDay: Codable {
        let weekIdx: Int
        let dayIdx: Int
        let date: Date?
        let exercises: [ExportDayExercise]
        let conditioning: ExportConditioning?
        var startedAt: Date? = nil
        var finishedAt: Date? = nil
        var skippedAt: Date? = nil
    }
    struct ExportDayExercise: Codable {
        let templateName: String
        let equipment: String
        var muscleGroup: String? = nil
        var restSec: Int? = nil
        var tempo: String? = nil
        var phaseMode: String? = nil
        var defaultSets: Int? = nil
        var defaultRepMin: Int? = nil
        var defaultRepMax: Int? = nil
        let sets: Int
        let targetWeight: Double?
        let targetRepsMin: Int
        let targetRepsMax: Int
        let phase: String
        let logs: [ExportLog]
        var targetNote: String? = nil
        var manualTarget: Bool? = nil
        var plannedRestSeconds: Int? = nil
    }
    struct ExportLog: Codable { let setIdx: Int; let actualWeight: Double?; let reps: Int; let rir: Double?; let timestamp: Date }
    struct ExportConditioning: Codable {
        let type: String
        let protocolText: String
        let targetZone: String?
        let targetPace: String?
        let durationMin: Int?
        var loggedMinutes: Int? = nil
        var loggedMeters: Int? = nil
        var loggedAt: Date? = nil
    }

    struct ExportRule: Codable {
        let templateName: String
        let equipment: String
        let type: String
        let paramsJSON: String
    }
    struct ExportPhase: Codable {
        let templateName: String
        let equipment: String
        let currentPhase: String
        let eligibilityScore: Double
        let blockStartLoad: Double?
        let lastSwitchAt: Date?
    }

    @MainActor static func exportJSON(context: ModelContext) throws -> Data {
        let programs = try context.fetch(FetchDescriptor<Program>())
        let active = programs.filter { !$0.isArchived }
        guard active.count <= 1, let program = active.first ?? Program.latestArchived(in: programs) else {
            throw BackupError.invalid("No workout history is available to export.")
        }
        let rules = try context.fetch(FetchDescriptor<ProgressionRule>())
        let phases = try context.fetch(FetchDescriptor<PhaseState>())
        var root = snapshot(program, rules: rules, phases: phases)
        // Archive-only backups use version 5. Active-cycle backups remain compatible with version 4 readers.
        if program.isArchived { root.formatVersion = 5 }
        let archivedCycles = programs.filter { $0.isArchived && $0 !== program }
            .sorted { ($0.archivedAt ?? .distantPast, $0.startDate) < ($1.archivedAt ?? .distantPast, $1.startDate) }
            .map { snapshot($0, rules: rules, phases: phases) }
        if !archivedCycles.isEmpty { root.archivedCycles = archivedCycles }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(root)
    }

    private static func snapshot(_ program: Program, rules: [ProgressionRule], phases: [PhaseState]) -> ExportProgram {
        let days = program.days.sorted { ($0.weekIdx, $0.dayIdx) < ($1.weekIdx, $1.dayIdx) }
        let dds: [ExportDay] = days.map { day in
            let exs = day.exercises.sorted { $0.orderIdx < $1.orderIdx }.map { ex in
                ExportDayExercise(
                    templateName: ex.template.name,
                    equipment: ex.template.equipment,
                    muscleGroup: ex.template.muscleGroup,
                    restSec: ex.template.restSec,
                    tempo: ex.template.tempo,
                    phaseMode: ex.template.phaseMode,
                    defaultSets: ex.template.defaultSets,
                    defaultRepMin: ex.template.repMin,
                    defaultRepMax: ex.template.repMax,
                    sets: ex.sets,
                    targetWeight: ex.targetWeight,
                    targetRepsMin: ex.targetRepsMin,
                    targetRepsMax: ex.targetRepsMax,
                    phase: ex.phase,
                    logs: exportLogs(ex.logs),
                    targetNote: ex.targetNote, manualTarget: ex.manualTarget, plannedRestSeconds: ex.plannedRestSeconds
                )
            }
            let cond = day.conditioning.map {
                ExportConditioning(type: $0.type, protocolText: $0.protocolText, targetZone: $0.targetZone,
                    targetPace: $0.targetPace, durationMin: $0.durationMin, loggedMinutes: $0.loggedMinutes,
                    loggedMeters: $0.loggedMeters, loggedAt: $0.loggedAt)
            }
            return ExportDay(weekIdx: day.weekIdx, dayIdx: day.dayIdx, date: day.date, exercises: exs, conditioning: cond, startedAt: day.startedAt, finishedAt: day.finishedAt,
                             skippedAt: day.skippedAt)
        }
        let templateIDs = Set(program.days.flatMap(\.exercises).map { $0.template.persistentModelID })
        let savedRules = rules.filter { templateIDs.contains($0.template.persistentModelID) }.map {
            ExportRule(templateName: $0.template.name, equipment: $0.template.equipment, type: $0.type, paramsJSON: $0.paramsJSON)
        }
        let savedPhases = phases.filter { templateIDs.contains($0.template.persistentModelID) }.map {
            ExportPhase(templateName: $0.template.name, equipment: $0.template.equipment, currentPhase: $0.currentPhase,
                eligibilityScore: $0.eligibilityScore, blockStartLoad: $0.blockStartLoad, lastSwitchAt: $0.lastSwitchAt)
        }
        return ExportProgram(name: program.name, startDate: program.startDate, totalWeeks: program.totalWeeks,
                             days: dds, rules: savedRules, phases: savedPhases, trackCode: program.trackCode,
                             deloadWeek: program.deloadWeek, archivedAt: program.archivedAt)
    }

    private static func exportLogs(_ logs: [ExerciseLog]) -> [ExportLog] {
        let ordered = logs.sorted { ($0.setIdx, $0.timestamp) < ($1.setIdx, $1.timestamp) }
        let duplicateIndices = Set(ordered.map(\.setIdx)).count != ordered.count
        return ordered.enumerated().map { index, log in
            ExportLog(setIdx: duplicateIndices ? index + 1 : log.setIdx, actualWeight: log.actualWeight,
                      reps: log.reps, rir: log.rir, timestamp: log.timestamp)
        }
    }

    enum BackupError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let reason): return reason }
        }
    }

    static func validatedProgram(_ data: Data) throws -> ExportProgram {
        let root = try JSONDecoder().decode(ExportProgram.self, from: data)
        guard root.archivedAt == nil || root.formatVersion == 5,
              (root.archivedCycles?.count ?? 0) <= 100 else {
            throw BackupError.invalid("This backup has invalid cycle history.")
        }
        try validate(root)
        for archive in root.archivedCycles ?? [] {
            guard archive.archivedAt != nil, archive.archivedCycles == nil else {
                throw BackupError.invalid("This backup has invalid cycle history.")
            }
            try validate(archive)
        }
        return root
    }

    private static func validate(_ root: ExportProgram) throws {
        guard (1...5).contains(root.formatVersion ?? 1), (1...104).contains(root.totalWeeks),
              !root.name.isEmpty, !root.days.isEmpty, root.days.count <= 728 else {
            throw BackupError.invalid("This backup has an unsupported version or invalid program.")
        }
        let activeCount = root.days.filter { $0.startedAt != nil && $0.finishedAt == nil && $0.skippedAt == nil }.count
        guard activeCount <= (root.archivedAt == nil ? 1 : 0) else {
            throw BackupError.invalid("This backup contains more than one active workout.")
        }
        guard root.trackCode.map({ TrainingTrack(rawValue: $0) != nil }) ?? true,
              root.deloadWeek.map({ $0 == root.totalWeeks && $0 > 1 && root.days.contains { day in day.weekIdx == root.totalWeeks } }) ?? true else {
            throw BackupError.invalid("This backup has invalid training track details.")
        }
        var dayKeys = Set<String>()
        for day in root.days {
            guard (1...root.totalWeeks).contains(day.weekIdx), (1...7).contains(day.dayIdx),
                  dayKeys.insert("\(day.weekIdx)-\(day.dayIdx)").inserted,
                  !day.exercises.isEmpty, day.exercises.count <= 100 else {
                throw BackupError.invalid("This backup contains invalid or duplicate training days.")
            }
            if let conditioning = day.conditioning {
                guard conditioning.loggedMinutes.map({ (1...600).contains($0) }) ?? true,
                      conditioning.loggedMeters.map({ (1...500_000).contains($0) }) ?? true else {
                    throw BackupError.invalid("This backup contains an invalid conditioning result.")
                }
            }
            for exercise in day.exercises {
                guard !exercise.templateName.isEmpty, (1...100).contains(exercise.sets),
                      (1...100).contains(exercise.targetRepsMin), exercise.targetRepsMax >= exercise.targetRepsMin,
                      exercise.targetRepsMax <= 100, ["HYP", "STR"].contains(exercise.phase),
                      exercise.targetWeight.map({ $0.isFinite && $0 >= 0 }) ?? true,
                      exercise.restSec.map({ (0...3600).contains($0) }) ?? true,
                      exercise.plannedRestSeconds.map({ (0...3600).contains($0) }) ?? true else {
                    throw BackupError.invalid("This backup contains an invalid exercise.")
                }
                var indexes = Set<Int>()
                for log in exercise.logs {
                    guard (1...100_000).contains(log.setIdx),
                          (indexes.insert(log.setIdx).inserted || (root.formatVersion ?? 1) == 1), log.reps > 0,
                          log.actualWeight.map({ $0.isFinite && $0 >= 0 }) ?? true,
                          log.rir.map({ $0.isFinite && (0...6).contains($0) }) ?? true else {
                        throw BackupError.invalid("This backup contains invalid or duplicate sets.")
                    }
                }
            }
        }
    }

    // Validate before touching live data, then save replacement in one operation.
    static func importJSON(_ data: Data, context: ModelContext) throws {
        let root = try validatedProgram(data)
        try context.save()
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        do {
            try removeAll(ExerciseLog.self, context: context)
            try removeAll(DayExercise.self, context: context)
            try removeAll(Conditioning.self, context: context)
            try removeAll(DayPlan.self, context: context)
            try removeAll(ProgressionRule.self, context: context)
            try removeAll(PhaseState.self, context: context)
            try removeAll(ExerciseTemplate.self, context: context)
            try removeAll(Program.self, context: context)
            for cycle in [root] + (root.archivedCycles ?? []) {
                try restore(cycle, context: context)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func restore(_ root: ExportProgram, context: ModelContext) throws {
        let program = Program(name: root.name, startDate: root.startDate, totalWeeks: root.totalWeeks)
        program.trackCode = root.trackCode
        program.deloadWeek = root.deloadWeek
        program.archivedAt = root.archivedAt
        context.insert(program)
        var templates: [String: ExerciseTemplate] = [:]
        for day in root.days {
            let d = DayPlan(program: program, weekIdx: day.weekIdx, dayIdx: day.dayIdx)
            d.date = day.date
            d.startedAt = day.startedAt
            d.finishedAt = day.finishedAt
            d.skippedAt = day.skippedAt
            context.insert(d)
            program.days.append(d)
            for (index, ex) in day.exercises.enumerated() {
                let key = ex.templateName + "|" + ex.equipment
                let template = templates[key] ?? ExerciseTemplate(name: ex.templateName,
                    muscleGroup: ex.muscleGroup ?? "", equipment: ex.equipment, defaultSets: ex.defaultSets ?? ex.sets,
                    repMin: ex.defaultRepMin ?? ex.targetRepsMin, repMax: ex.defaultRepMax ?? ex.targetRepsMax, restSec: ex.restSec ?? 120,
                    tempo: ex.tempo, phaseMode: ex.phaseMode ?? "AUTO")
                if templates[key] == nil {
                    context.insert(template)
                    templates[key] = template
                }
                let de = DayExercise(day: d, template: template, targetWeight: ex.targetWeight,
                    targetRepsMin: ex.targetRepsMin, targetRepsMax: ex.targetRepsMax,
                    sets: ex.sets, orderIdx: index, phase: ex.phase)
                de.targetNote = ex.targetNote
                de.manualTarget = ex.manualTarget
                de.plannedRestSeconds = ex.plannedRestSeconds
                context.insert(de)
                d.exercises.append(de)
                let duplicateIndices = Set(ex.logs.map(\.setIdx)).count != ex.logs.count
                for (index, value) in ex.logs.enumerated() {
                    let log = ExerciseLog(dayExercise: de, setIdx: duplicateIndices ? index + 1 : value.setIdx,
                        actualWeight: value.actualWeight,
                        reps: value.reps, rir: value.rir, timestamp: value.timestamp)
                    context.insert(log)
                    if !de.logs.contains(where: { $0 === log }) { de.logs.append(log) }
                }
            }
            if let c = day.conditioning {
                let conditioning = Conditioning(day: d, type: c.type, protocolText: c.protocolText,
                    targetZone: c.targetZone, targetPace: c.targetPace, durationMin: c.durationMin)
                conditioning.loggedMinutes = c.loggedMinutes
                conditioning.loggedMeters = c.loggedMeters
                conditioning.loggedAt = c.loggedAt
                context.insert(conditioning)
                d.conditioning = conditioning
            }
        }
        for rule in root.rules ?? [] {
            guard let template = templates[rule.templateName + "|" + rule.equipment] else {
                throw BackupError.invalid("A progression rule refers to a missing exercise.")
            }
            context.insert(ProgressionRule(template: template, type: rule.type, paramsJSON: rule.paramsJSON))
        }
        for value in root.phases ?? [] {
            guard let template = templates[value.templateName + "|" + value.equipment] else {
                throw BackupError.invalid("A training phase refers to a missing exercise.")
            }
            let state = PhaseState(template: template, currentPhase: value.currentPhase)
            state.eligibilityScore = value.eligibilityScore
            state.blockStartLoad = value.blockStartLoad
            state.lastSwitchAt = value.lastSwitchAt
            context.insert(state)
        }
    }

    private static func removeAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) { context.delete(model) }
    }
}
