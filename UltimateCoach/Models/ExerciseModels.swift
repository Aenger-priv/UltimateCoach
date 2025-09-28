import Foundation
import SwiftData

@Model
final class ExerciseTemplate {
    var name: String
    var muscleGroup: String
    var equipment: String // "barbell","dumbbell","kettlebell","bodyweight","cable"
    var defaultSets: Int
    var repMin: Int
    var repMax: Int
    var restSec: Int
    var tempo: String?
    var phaseMode: String // "AUTO","HYP","STR"

    init(name: String,
         muscleGroup: String,
         equipment: String,
         defaultSets: Int,
         repMin: Int,
         repMax: Int,
         restSec: Int,
         tempo: String? = nil,
         phaseMode: String = "AUTO") {
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.defaultSets = defaultSets
        self.repMin = repMin
        self.repMax = repMax
        self.restSec = restSec
        self.tempo = tempo
        self.phaseMode = phaseMode
    }
}

@Model
final class DayExercise {
    var day: DayPlan
    var template: ExerciseTemplate
    var targetWeight: Double? // kg
    var targetRepsMin: Int
    var targetRepsMax: Int
    var sets: Int
    var orderIdx: Int
    var phase: String // "HYP" or "STR"
    @Relationship(deleteRule: .cascade) var logs: [ExerciseLog]

    init(day: DayPlan,
         template: ExerciseTemplate,
         targetWeight: Double?,
         targetRepsMin: Int,
         targetRepsMax: Int,
         sets: Int,
         orderIdx: Int,
         phase: String) {
        self.day = day
        self.template = template
        self.targetWeight = targetWeight
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.sets = sets
        self.orderIdx = orderIdx
        self.phase = phase
        self.logs = []
    }
}

@Model
final class ExerciseLog {
    var dayExercise: DayExercise
    var setIdx: Int
    var actualWeight: Double?
    var reps: Int
    var rir: Double?
    var timestamp: Date

    init(dayExercise: DayExercise,
         setIdx: Int,
         actualWeight: Double?,
         reps: Int,
         rir: Double?,
         timestamp: Date = Date()) {
        self.dayExercise = dayExercise
        self.setIdx = setIdx
        self.actualWeight = actualWeight
        self.reps = reps
        self.rir = rir
        self.timestamp = timestamp
    }
}

@Model
final class ProgressionRule {
    var template: ExerciseTemplate
    var type: String // "double_progression"
    var paramsJSON: String // increments, deload thresholds

    init(template: ExerciseTemplate,
         type: String = "double_progression",
         paramsJSON: String = "{}") {
        self.template = template
        self.type = type
        self.paramsJSON = paramsJSON
    }
}

@Model
final class PhaseState {
    var template: ExerciseTemplate
    var currentPhase: String // "HYP" or "STR"
    var eligibilityScore: Double
    var blockStartLoad: Double?
    var lastSwitchAt: Date?

    init(template: ExerciseTemplate, currentPhase: String = "HYP") {
        self.template = template
        self.currentPhase = currentPhase
        self.eligibilityScore = 0
        self.blockStartLoad = nil
        self.lastSwitchAt = nil
    }
}

@Model
final class Conditioning {
    var day: DayPlan
    var type: String // "row","treadmill"
    var protocolText: String // e.g., "6x500m/90s"
    var targetZone: String?
    var targetPace: String?
    var durationMin: Int?

    init(day: DayPlan,
         type: String,
         protocolText: String,
         targetZone: String? = nil,
         targetPace: String? = nil,
         durationMin: Int? = nil) {
        self.day = day
        self.type = type
        self.protocolText = protocolText
        self.targetZone = targetZone
        self.targetPace = targetPace
        self.durationMin = durationMin
    }
}

