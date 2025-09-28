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

    @MainActor static func seedIfNeeded(context: ModelContext, overrideStartDate: Date? = nil) async {
        let dayFetch = FetchDescriptor<DayPlan>(predicate: #Predicate<DayPlan> { _ in true })
        if let count = try? context.fetchCount(dayFetch), count > 0 {
            Self.lastStatus = "Seed skipped: existing days=\(count)"
            return
        }
        let existingProgram = (try? context.fetch(FetchDescriptor<Program>()))?.first

        // Load embedded seed if bundle resource missing
        let data: Data
        if let url = Bundle.main.url(forResource: "program_seed", withExtension: "json") {
            if let d = try? Data(contentsOf: url) {
                data = d
                Self.lastStatus = "Using bundled JSON"
            } else {
                data = Data(embeddedSeedJSON.utf8)
                Self.lastStatus = "Bundled JSON unreadable; using embedded"
            }
        } else {
            data = Data(embeddedSeedJSON.utf8)
            Self.lastStatus = "No bundled JSON; using embedded"
        }
        do {
            let decoder = JSONDecoder()
            let cfg = try decoder.decode(SeedConfig.self, from: data)
            
            let start = Calendar.current.startOfDay(for: overrideStartDate ?? (existingProgram?.startDate ?? (ISO8601DateFormatter().date(from: cfg.startDateISO8601) ?? Date())))
            let program: Program
            if let p = existingProgram {
                program = p
                program.startDate = start
            } else {
                program = Program(name: cfg.programName, startDate: start, totalWeeks: cfg.totalWeeks)
                context.insert(program)
            }
            
            var insertedDaysCount = 0

            var templatesByName: [String: ExerciseTemplate] = [:]

            for week in 1...program.totalWeeks {
                for dayTpl in cfg.dayTemplates.sorted(by: { $0.dayIdx < $1.dayIdx }) {
                    let day = DayPlan(program: program, weekIdx: week, dayIdx: dayTpl.dayIdx)
                    day.date = computeDate(start: start, weekIdx: week, dayIdx: dayTpl.dayIdx)
                    context.insert(day)
                    program.days.append(day)
                    insertedDaysCount += 1
                    // Exercises
                    var order = 0
                    for ex in dayTpl.exercises {
                        let tpl: ExerciseTemplate
                        if let existing = templatesByName[ex.name] {
                            tpl = existing
                        } else {
                            tpl = ExerciseTemplate(
                                name: ex.name,
                                muscleGroup: ex.muscleGroup,
                                equipment: ex.equipment,
                                defaultSets: ex.sets,
                                repMin: ex.repMin,
                                repMax: ex.repMax,
                                restSec: ex.restSec,
                                tempo: ex.tempo,
                                phaseMode: "AUTO"
                            )
                            templatesByName[ex.name] = tpl
                            context.insert(tpl)
                        }
                        let dayEx = DayExercise(
                            day: day,
                            template: tpl,
                            targetWeight: ex.targetWeight,
                            targetRepsMin: ex.repMin,
                            targetRepsMax: ex.repMax,
                            sets: ex.sets,
                            orderIdx: order,
                            phase: "HYP"
                        )
                        context.insert(dayEx)
                        day.exercises.append(dayEx)
                        order += 1
                    }
                    if let c = dayTpl.conditioning {
                        let cond = Conditioning(
                            day: day,
                            type: c.type,
                            protocolText: c.protocolText,
                            targetZone: c.targetZone,
                            targetPace: c.targetPace,
                            durationMin: c.durationMin
                        )
                        context.insert(cond)
                        day.conditioning = cond
                    }
                }
            }
            
            if insertedDaysCount == 0 {
                // Fallback if JSON had no day templates: create a minimal day 1
                let day = DayPlan(program: program, weekIdx: 1, dayIdx: 1)
                day.date = computeDate(start: start, weekIdx: 1, dayIdx: 1)
                context.insert(day)
                program.days.append(day)
                let bench = ExerciseTemplate(
                    name: "Bench Press",
                    muscleGroup: "chest",
                    equipment: "barbell",
                    defaultSets: 3,
                    repMin: 8,
                    repMax: 12,
                    restSec: 120
                )
                context.insert(bench)
                let ex = DayExercise(
                    day: day,
                    template: bench,
                    targetWeight: 60,
                    targetRepsMin: 8,
                    targetRepsMax: 12,
                    sets: 3,
                    orderIdx: 0,
                    phase: "HYP"
                )
                context.insert(ex)
                day.exercises.append(ex)
            }

            do {
                try context.save()
                Self.lastStatus = "Seed OK: program=\(program.name), weeks=\(program.totalWeeks)"
            } catch {
                Self.lastStatus = "Seed save error: \(error.localizedDescription)"
                throw error
            }
        } catch {
            print("Seed error: \(error)")
            Self.lastStatus = "Seed error: \(error.localizedDescription)"
            // Fallback: create a minimal default program/day if JSON decoding failed
            let start = Calendar.current.startOfDay(for: overrideStartDate ?? Date())
            let program: Program
            if let p = (try? context.fetch(FetchDescriptor<Program>()))?.first {
                program = p
                program.startDate = start
            } else {
                program = Program(name: "Default Program", startDate: start, totalWeeks: 12)
                context.insert(program)
            }
            let day = DayPlan(program: program, weekIdx: 1, dayIdx: 1)
            day.date = computeDate(start: start, weekIdx: 1, dayIdx: 1)
            context.insert(day)
            let bench = ExerciseTemplate(name: "Bench Press", muscleGroup: "chest", equipment: "barbell", defaultSets: 3, repMin: 8, repMax: 12, restSec: 120)
            context.insert(bench)
            let ex = DayExercise(day: day, template: bench, targetWeight: 60, targetRepsMin: 8, targetRepsMax: 12, sets: 3, orderIdx: 0, phase: "HYP")
            context.insert(ex)
            do {
                try context.save()
                Self.lastStatus += " | Fallback seed OK"
            } catch {
                print("Seed save error (catch fallback): \(error)")
                Self.lastStatus += " | Fallback save error: \(error.localizedDescription)"
            }
        }
    }

    @MainActor static func fillMissingExercisesIfNeeded(context: ModelContext) async {
        // Find any days without exercises and populate from seed template for that dayIdx
        do {
            let days = try context.fetch(FetchDescriptor<DayPlan>())
            guard days.contains(where: { $0.exercises.isEmpty }) else {
                return
            }
            // Load seed templates
            let data: Data
            if let url = Bundle.main.url(forResource: "program_seed", withExtension: "json"), let d = try? Data(contentsOf: url) {
                data = d
            } else {
                data = Data(embeddedSeedJSON.utf8)
            }
            let cfg = try JSONDecoder().decode(SeedConfig.self, from: data)
            // Map name->template to reuse
            var templatesByName: [String: ExerciseTemplate] = Dictionary(uniqueKeysWithValues: (try context.fetch(FetchDescriptor<ExerciseTemplate>())).map { ($0.name, $0) })

            for day in days where day.exercises.isEmpty {
                if let dayTpl = cfg.dayTemplates.first(where: { $0.dayIdx == day.dayIdx }) {
                    var order = 0
                    for ex in dayTpl.exercises {
                        let tpl: ExerciseTemplate
                        if let existing = templatesByName[ex.name] {
                            tpl = existing
                        } else {
                            tpl = ExerciseTemplate(name: ex.name, muscleGroup: ex.muscleGroup, equipment: ex.equipment, defaultSets: ex.sets, repMin: ex.repMin, repMax: ex.repMax, restSec: ex.restSec, tempo: ex.tempo, phaseMode: "AUTO")
                            context.insert(tpl)
                            templatesByName[ex.name] = tpl
                        }
                        let dayEx = DayExercise(day: day, template: tpl, targetWeight: ex.targetWeight, targetRepsMin: ex.repMin, targetRepsMax: ex.repMax, sets: ex.sets, orderIdx: order, phase: "HYP")
                        context.insert(dayEx)
                        day.exercises.append(dayEx)
                        order += 1
                    }
                    if day.conditioning == nil, let c = dayTpl.conditioning {
                        let cond = Conditioning(day: day, type: c.type, protocolText: c.protocolText, targetZone: c.targetZone, targetPace: c.targetPace, durationMin: c.durationMin)
                        context.insert(cond)
                        day.conditioning = cond
                    }
                }
            }
            try context.save()
            Self.lastStatus = (Self.lastStatus + " | Filled missing exercises")
        } catch {
            print("fillMissingExercisesIfNeeded error: \(error)")
            Self.lastStatus = (Self.lastStatus + " | Fill error: \(error.localizedDescription)")
        }
    }

    // Day index is treated as day-of-week offset relative to program start date.
    // Example: dayIdx 1 = startDate, 2 = +1 day, 5 = +4 days.
    static func computeDate(start: Date, weekIdx: Int, dayIdx: Int) -> Date {
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: (weekIdx - 1) * 7, to: start) ?? start
        return cal.date(byAdding: .day, value: max(0, dayIdx - 1), to: base) ?? base
    }
}

private let embeddedSeedJSON = """
{
  "programName": "12 Week Strength+Hypertrophy",
  "totalWeeks": 12,
  "startDateISO8601": "2025-01-06T08:00:00Z",
  "dayTemplates": [
    {
      "dayIdx": 1,
      "exercises": [
        {"name": "Bench Press", "muscleGroup": "chest", "equipment": "barbell", "sets": 4, "repMin": 8, "repMax": 12, "restSec": 120, "tempo": null, "targetWeight": 60.0},
        {"name": "Overhead Press", "muscleGroup": "shoulders", "equipment": "barbell", "sets": 3, "repMin": 8, "repMax": 10, "restSec": 120, "tempo": null, "targetWeight": 35.0},
        {"name": "Incline DB Press", "muscleGroup": "chest", "equipment": "dumbbell", "sets": 3, "repMin": 10, "repMax": 12, "restSec": 120, "tempo": null, "targetWeight": 20.0},
        {"name": "DB Curl", "muscleGroup": "biceps", "equipment": "dumbbell", "sets": 3, "repMin": 10, "repMax": 12, "restSec": 90, "tempo": null, "targetWeight": 12.5},
        {"name": "Dips", "muscleGroup": "triceps", "equipment": "bodyweight", "sets": 3, "repMin": 8, "repMax": 12, "restSec": 120, "tempo": null, "targetWeight": null}
      ],
      "conditioning": {"type": "row", "protocolText": "6x500m/90s", "targetZone": null, "targetPace": null, "durationMin": null}
    },
    {
      "dayIdx": 2,
      "exercises": [
        {"name": "Back Squat", "muscleGroup": "legs", "equipment": "barbell", "sets": 4, "repMin": 6, "repMax": 10, "restSec": 180, "tempo": null, "targetWeight": 80.0},
        {"name": "Romanian Deadlift", "muscleGroup": "hamstrings", "equipment": "barbell", "sets": 3, "repMin": 8, "repMax": 10, "restSec": 150, "tempo": null, "targetWeight": 70.0},
        {"name": "Bulgarian Split Squat", "muscleGroup": "legs", "equipment": "dumbbell", "sets": 3, "repMin": 10, "repMax": 12, "restSec": 120, "tempo": null, "targetWeight": 20.0}
      ],
      "conditioning": {"type": "row", "protocolText": "Zone2 25-30m", "targetZone": "Z2", "targetPace": null, "durationMin": 25}
    },
    {
      "dayIdx": 3,
      "exercises": [
        {"name": "Pull-Ups", "muscleGroup": "back", "equipment": "bodyweight", "sets": 4, "repMin": 6, "repMax": 10, "restSec": 120, "tempo": null, "targetWeight": null},
        {"name": "Barbell Row", "muscleGroup": "back", "equipment": "barbell", "sets": 3, "repMin": 8, "repMax": 12, "restSec": 120, "tempo": null, "targetWeight": 60.0},
        {"name": "Chin-Ups", "muscleGroup": "back", "equipment": "bodyweight", "sets": 3, "repMin": 6, "repMax": 10, "restSec": 120, "tempo": null, "targetWeight": null},
        {"name": "Incline DB Curl", "muscleGroup": "biceps", "equipment": "dumbbell", "sets": 3, "repMin": 10, "repMax": 12, "restSec": 90, "tempo": null, "targetWeight": 12.5},
        {"name": "Overhead Triceps Extension", "muscleGroup": "triceps", "equipment": "dumbbell", "sets": 3, "repMin": 10, "repMax": 12, "restSec": 90, "tempo": null, "targetWeight": 15.0}
      ],
      "conditioning": {"type": "row", "protocolText": "Tabata 8x20/10", "targetZone": null, "targetPace": null, "durationMin": null}
    },
    {
      "dayIdx": 5,
      "exercises": [
        {"name": "Incline DB Press", "muscleGroup": "chest", "equipment": "dumbbell", "sets": 3, "repMin": 8, "repMax": 12, "restSec": 120, "tempo": null, "targetWeight": 22.5},
        {"name": "One-Arm Row", "muscleGroup": "back", "equipment": "dumbbell", "sets": 3, "repMin": 10, "repMax": 12, "restSec": 120, "tempo": null, "targetWeight": 25.0},
        {"name": "Lateral Raise", "muscleGroup": "shoulders", "equipment": "dumbbell", "sets": 3, "repMin": 12, "repMax": 15, "restSec": 90, "tempo": null, "targetWeight": 7.5},
        {"name": "Chin-Ups", "muscleGroup": "back", "equipment": "bodyweight", "sets": 3, "repMin": 6, "repMax": 10, "restSec": 120, "tempo": null, "targetWeight": null},
        {"name": "Hammer Curl", "muscleGroup": "biceps", "equipment": "dumbbell", "sets": 3, "repMin": 10, "repMax": 12, "restSec": 90, "tempo": null, "targetWeight": 12.5},
        {"name": "Dips", "muscleGroup": "triceps", "equipment": "bodyweight", "sets": 3, "repMin": 8, "repMax": 12, "restSec": 120, "tempo": null, "targetWeight": null}
      ],
      "conditioning": {"type": "row", "protocolText": "20m progressive", "targetZone": "Z2", "targetPace": null, "durationMin": 20}
    }
  ]
}
"""
