import Foundation
import SwiftData

struct SeedData {
    static var lastStatus: String = ""
    struct SeedConfig: Codable {
        let programName: String
        let totalWeeks: Int
        let startDateISO8601: String
        let dayTemplates: [DayTemplate]
    }
    struct DayTemplate: Codable {
        let dayIdx: Int
        let exercises: [ExerciseSpec]
        let conditioning: ConditioningSpec?
    }
    struct ExerciseSpec: Codable {
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
    struct ConditioningSpec: Codable {
        let type: String
        let protocolText: String
        let targetZone: String?
        let targetPace: String?
        let durationMin: Int?
    }

    @MainActor static func seedIfNeeded(context: ModelContext, overrideStartDate: Date? = nil) async throws {
        guard try context.fetchCount(FetchDescriptor<Program>()) == 0 else { return }
        guard let url = Bundle.main.url(forResource: "program_seed", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let cfg = try JSONDecoder().decode(SeedConfig.self, from: Data(contentsOf: url))
        guard cfg.totalWeeks > 0, !cfg.dayTemplates.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        let start = Calendar.current.startOfDay(for: overrideStartDate ?? Date())
        let program = Program(name: cfg.programName, startDate: start, totalWeeks: cfg.totalWeeks)
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        do {
            context.insert(program)
            var templates: [String: ExerciseTemplate] = [:]
            for week in 1...cfg.totalWeeks {
                for spec in cfg.dayTemplates.sorted(by: { $0.dayIdx < $1.dayIdx }) {
                    let day = DayPlan(program: program, weekIdx: week, dayIdx: spec.dayIdx)
                    day.date = computeDate(start: start, weekIdx: week, dayIdx: spec.dayIdx)
                    context.insert(day)
                    program.days.append(day)
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
                        let exercise = DayExercise(day: day, template: template, targetWeight: ex.targetWeight,
                            targetRepsMin: ex.repMin, targetRepsMax: ex.repMax, sets: ex.sets,
                            orderIdx: index, phase: "HYP")
                        context.insert(exercise)
                        day.exercises.append(exercise)
                    }
                    if let c = spec.conditioning {
                        let conditioning = Conditioning(day: day, type: c.type, protocolText: c.protocolText,
                            targetZone: c.targetZone, targetPace: c.targetPace, durationMin: c.durationMin)
                        context.insert(conditioning)
                        day.conditioning = conditioning
                    }
                }
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func computeDate(start: Date, weekIdx: Int, dayIdx: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: (weekIdx - 1) * 7 + max(0, dayIdx - 1), to: start) ?? start
    }
}
