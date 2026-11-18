import Foundation

// The scheduled phase advances by date. A new track takes effect only after confirmation.
nonisolated enum TrainingCycle {
    static let trainingWeeks = 12
    static let deloadWeek = trainingWeeks + 1

    enum Stage: Equatable {
        case training
        case deload
        case readyForNextTrack
    }

    static func stage(on date: Date, trainingEnds: Date, cycleEnds: Date, hasDeload: Bool,
                      hasActiveWorkout: Bool) -> Stage {
        if date < trainingEnds { return .training }
        if date < cycleEnds || hasActiveWorkout { return hasDeload ? .deload : .training }
        return .readyForNextTrack
    }

    static func recoverySets(from sets: Int) -> Int { max(1, (sets + 1) / 2) }

    static func startingLoad(previousWeight: Double, previousReps: Int, targetReps: Int) -> Double {
        let ceiling = previousWeight * 0.9
        let adjustedForReps = previousWeight * (30 + Double(min(12, previousReps))) / (33 + Double(targetReps))
        return floor(min(500, ceiling, adjustedForReps) * 10) / 10
    }

    static func recoveryLoad(from weight: Double?) -> Double? {
        weight.map { floor($0 * 0.85 * 10) / 10 }
    }
}
