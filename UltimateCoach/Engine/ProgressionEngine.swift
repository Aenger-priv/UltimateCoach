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
    blockStartLoad: Double?,
    minimumReserve: Double? = nil
) -> Target {
    // Never progress from missing, partial, invalid, or lighter-than-prescribed work.
    guard lastTarget.sets > 0, lastLogs.count == lastTarget.sets,
          lastLogs.allSatisfy({ $0.reps > 0 && ($0.weight.map { $0.isFinite && $0 >= 0 } ?? true)
              && ($0.rir.map { $0.isFinite && $0 >= 0 && $0 <= 6 } ?? true) }),
          rule.barbellInc.isFinite, rule.barbellInc > 0,
          rule.dbInc.isFinite, rule.dbInc > 0,
          rule.deloadPct.isFinite, (0..<1).contains(rule.deloadPct), rule.missLimit > 0
    else { return lastTarget }
    if let prescribed = lastTarget.weight,
       lastLogs.contains(where: { ($0.weight ?? 0) + 0.005 < prescribed }) {
        return lastTarget
    }
    let requiredReserve = minimumReserve ?? (phase == "HYP" ? 2.0 : 1.0)
    let reachedTop = lastLogs.allSatisfy { $0.reps >= lastTarget.repMax }
    let enoughReserve = lastLogs.allSatisfy { ($0.rir ?? requiredReserve) >= requiredReserve }
    let missedRepFloor = lastLogs.contains { $0.reps < lastTarget.repMin }
    let increment = rule.equipment == "barbell" ? rule.barbellInc : rule.dbInc

    // Bodyweight work needs its own added-load policy. A missing external load is not a baseline.
    guard let weight = lastTarget.weight else { return lastTarget }
    let nextWeight: Double
    if reachedTop && enoughReserve {
        nextWeight = roundToIncrement(weight + increment, increment)
    } else if missedRepFloor && consecutiveMisses + 1 >= rule.missLimit {
        nextWeight = roundToIncrement(weight * (1 - rule.deloadPct), increment)
    } else {
        return lastTarget
    }
    return Target(weight: nextWeight, repMin: lastTarget.repMin, repMax: lastTarget.repMax,
                  sets: lastTarget.sets, phase: phase)
}

public func estimate1RM(weight: Double, reps: Int) -> Double {
    epley1RM(weight: weight, reps: reps)
}

// MARK: - Helpers
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

