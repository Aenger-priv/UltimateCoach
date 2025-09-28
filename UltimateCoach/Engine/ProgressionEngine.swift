import Foundation

// MARK: - Engine Types
public struct SetLog: Equatable {
    public let weight: Double?
    public let reps: Int
    public let rir: Double?
    public init(weight: Double?, reps: Int, rir: Double?) {
        self.weight = weight
        self.reps = reps
        self.rir = rir
    }
}

public struct Target: Equatable {
    public let weight: Double?
    public let repMin: Int
    public let repMax: Int
    public let sets: Int
    public let phase: String // "HYP" or "STR"
    public init(weight: Double?, repMin: Int, repMax: Int, sets: Int, phase: String) {
        self.weight = weight
        self.repMin = repMin
        self.repMax = repMax
        self.sets = sets
        self.phase = phase
    }
}

public struct Rule: Equatable {
    public let equipment: String // barbell,dumbbell,bodyweight, etc
    public let barbellInc: Double
    public let dbInc: Double
    public let deloadPct: Double
    public let missLimit: Int
    public init(equipment: String, barbellInc: Double, dbInc: Double, deloadPct: Double, missLimit: Int) {
        self.equipment = equipment
        self.barbellInc = barbellInc
        self.dbInc = dbInc
        self.deloadPct = deloadPct
        self.missLimit = missLimit
    }
}

// MARK: - Core Engine
public func computeNextTargets(
    lastLogs: [SetLog],
    lastTarget: Target,
    rule: Rule,
    phase: String,
    consecutiveMisses: Int,
    blockStartLoad: Double?
) -> Target {
    let top = lastTarget.repMax
    let minReps = lastTarget.repMin
    let targetRIRTop: Double = (phase == "HYP") ? 2.0 : 1.0
    let avgRIR: Double = averageRIR(lastLogs) ?? targetRIRTop
    let allAtTop = lastLogs.allSatisfy { $0.reps >= top }
    let allAtOrBelowRIR = lastLogs.allSatisfy { ($0.rir ?? targetRIRTop) <= targetRIRTop }
    let anyMiss = lastLogs.contains { $0.reps < minReps } || (avgRIR > 4)

    var nextWeight = lastTarget.weight
    var nextRepMin = lastTarget.repMin
    var nextRepMax = lastTarget.repMax
    let inc = (rule.equipment == "barbell") ? rule.barbellInc : rule.dbInc

    if allAtTop && allAtOrBelowRIR {
        if let w = lastTarget.weight {
            nextWeight = roundToIncrement(w + inc, inc)
        } else {
            nextWeight = roundToIncrement(inc, inc)
        }
    } else if consecutiveMisses + (anyMiss ? 1 : 0) >= rule.missLimit {
        if let w = lastTarget.weight {
            nextWeight = roundToIncrement(w * (1.0 - rule.deloadPct), inc)
        }
    } else if avgRIR > 3 {
        // Reduce target rep range for next time (keep load)
        nextRepMax = max(minReps, lastTarget.repMax - 1)
        nextRepMin = min(nextRepMax, max(1, lastTarget.repMin - 1))
    }

    return Target(weight: nextWeight, repMin: nextRepMin, repMax: nextRepMax, sets: lastTarget.sets, phase: phase)
}

public func estimate1RM(weight: Double, reps: Int) -> Double {
    guard reps > 0 else { return weight }
    return weight * (1.0 + Double(reps) / 30.0)
}

// MARK: - Helpers
private func averageRIR(_ logs: [SetLog]) -> Double? {
    let vals = logs.compactMap { $0.rir }
    guard !vals.isEmpty else { return nil }
    return vals.reduce(0, +) / Double(vals.count)
}

private func roundToIncrement(_ value: Double, _ inc: Double) -> Double {
    guard inc > 0 else { return value }
    let steps = (value / inc).rounded()
    return (steps * inc).rounded(toPlaces: 2)
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}

