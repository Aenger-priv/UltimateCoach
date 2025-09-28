import Foundation

public func aggregatePullupVolume(logs: [SetLog]) -> (totalReps: Int, suggestedWeightDelta: Double) {
    let total = logs.reduce(0) { $0 + $1.reps }
    // Heuristics per requirements
    let anyWeighted = logs.contains { ($0.weight ?? 0) > 0 }
    if total >= 32 {
        return (total, 2.5)
    }
    if anyWeighted && total < 20 {
        return (total, -2.5)
    }
    return (total, 0)
}

