import Foundation
import SwiftData

// Lightweight export/import using DTOs to avoid SwiftData graph encoding.
struct ExportImport {
    struct ExportProgram: Codable {
        let name: String
        let startDate: Date
        let totalWeeks: Int
        let days: [ExportDay]
    }
    struct ExportDay: Codable {
        let weekIdx: Int
        let dayIdx: Int
        let date: Date?
        let exercises: [ExportDayExercise]
        let conditioning: ExportConditioning?
    }
    struct ExportDayExercise: Codable {
        let templateName: String
        let equipment: String
        let sets: Int
        let targetWeight: Double?
        let targetRepsMin: Int
        let targetRepsMax: Int
        let phase: String
        let logs: [ExportLog]
    }
    struct ExportLog: Codable { let setIdx: Int; let actualWeight: Double?; let reps: Int; let rir: Double?; let timestamp: Date }
    struct ExportConditioning: Codable { let type: String; let protocolText: String; let targetZone: String?; let targetPace: String?; let durationMin: Int? }

    static func exportJSON(context: ModelContext) throws -> Data {
        let programs = try context.fetch(FetchDescriptor<Program>())
        guard let program = programs.first else { return Data() }
        let days = program.days.sorted { ($0.weekIdx, $0.dayIdx) < ($1.weekIdx, $1.dayIdx) }
        let dds: [ExportDay] = days.map { day in
            let exs = day.exercises.sorted { $0.orderIdx < $1.orderIdx }.map { ex in
                ExportDayExercise(
                    templateName: ex.template.name,
                    equipment: ex.template.equipment,
                    sets: ex.sets,
                    targetWeight: ex.targetWeight,
                    targetRepsMin: ex.targetRepsMin,
                    targetRepsMax: ex.targetRepsMax,
                    phase: ex.phase,
                    logs: ex.logs.sorted { $0.setIdx < $1.setIdx }.map { ExportLog(setIdx: $0.setIdx, actualWeight: $0.actualWeight, reps: $0.reps, rir: $0.rir, timestamp: $0.timestamp) }
                )
            }
            let cond: ExportConditioning? = day.conditioning.map { ExportConditioning(type: $0.type, protocolText: $0.protocolText, targetZone: $0.targetZone, targetPace: $0.targetPace, durationMin: $0.durationMin) }
            return ExportDay(weekIdx: day.weekIdx, dayIdx: day.dayIdx, date: day.date, exercises: exs, conditioning: cond)
        }
        let root = ExportProgram(name: program.name, startDate: program.startDate, totalWeeks: program.totalWeeks, days: dds)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(root)
    }

    static func importJSON(_ data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        let root = try decoder.decode(ExportProgram.self, from: data)
        try context.delete(model: Program.self)
        let program = Program(name: root.name, startDate: root.startDate, totalWeeks: root.totalWeeks)
        context.insert(program)
        var templates: [String: ExerciseTemplate] = [:]
        for day in root.days {
            let d = DayPlan(program: program, weekIdx: day.weekIdx, dayIdx: day.dayIdx)
            d.date = day.date
            context.insert(d)
            for (idx, ex) in day.exercises.enumerated() {
                let tpl = templates[ex.templateName] ?? {
                    let t = ExerciseTemplate(name: ex.templateName, muscleGroup: "", equipment: ex.equipment, defaultSets: ex.sets, repMin: ex.targetRepsMin, repMax: ex.targetRepsMax, restSec: 120)
                    templates[ex.templateName] = t
                    context.insert(t)
                    return t
                }()
                let de = DayExercise(day: d, template: tpl, targetWeight: ex.targetWeight, targetRepsMin: ex.targetRepsMin, targetRepsMax: ex.targetRepsMax, sets: ex.sets, orderIdx: idx, phase: ex.phase)
                context.insert(de)
                ex.logs.forEach { l in
                    context.insert(ExerciseLog(dayExercise: de, setIdx: l.setIdx, actualWeight: l.actualWeight, reps: l.reps, rir: l.rir, timestamp: l.timestamp))
                }
            }
            if let c = day.conditioning {
                let cond = Conditioning(day: d, type: c.type, protocolText: c.protocolText, targetZone: c.targetZone, targetPace: c.targetPace, durationMin: c.durationMin)
                context.insert(cond)
                d.conditioning = cond
            }
        }
    }
}

private extension ModelContext {
    func delete<T: PersistentModel>(model: T.Type) throws {
        let items = try fetch(FetchDescriptor<T>())
        items.forEach { delete($0) }
        try save()
    }
}
