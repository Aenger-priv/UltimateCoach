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

// A single prescription and the work actually recorded against it.
struct LiftExposure {
    let target: Target
    let logs: [SetLog]
    let reserve: Double

    private static let loadTolerance = 0.005 // kg, including lb entry round trips

    var topSets: Int {
        logs.filter { log in
            valid(log) && atLeastTargetLoad(log) && log.reps >= target.repMax && (log.rir ?? reserve) >= reserve
        }.count
    }

    var complete: Bool {
        target.sets > 0 && logs.count == target.sets && logs.allSatisfy(valid)
    }

    var ready: Bool { complete && topSets == target.sets }
    var missedFloor: Bool {
        complete && logs.allSatisfy(atLeastTargetLoad) &&
            logs.contains { $0.reps < target.repMin && atTargetLoad($0) }
    }

    func matchesPrescription(of other: LiftExposure) -> Bool {
        target.phase == other.target.phase && target.sets == other.target.sets &&
            target.repMin == other.target.repMin && target.repMax == other.target.repMax &&
            abs((target.weight ?? -1) - (other.target.weight ?? -1)) <= Self.loadTolerance
    }

    func sameRepsAndLoad(as other: LiftExposure) -> Bool {
        complete && logs.allSatisfy(atTargetLoad) && other.logs.allSatisfy(other.atTargetLoad) &&
            logs.reduce(0) { $0 + $1.reps } == other.logs.reduce(0) { $0 + $1.reps }
    }

    private func valid(_ log: SetLog) -> Bool {
        (1...100).contains(log.reps) && (log.weight.map { $0.isFinite && (0...500.001).contains($0) } ?? true) &&
            (log.rir.map { $0.isFinite && (0...6).contains($0) } ?? true)
    }

    private func atLeastTargetLoad(_ log: SetLog) -> Bool {
        (log.weight ?? 0) + Self.loadTolerance >= (target.weight ?? 0)
    }

    private func atTargetLoad(_ log: SetLog) -> Bool {
        abs((log.weight ?? 0) - (target.weight ?? 0)) <= Self.loadTolerance
    }
}

struct LiftRecommendation {
    enum Reason: Equatable {
        case repeatTarget, recoverReserve, confirmTopSets, increase, incrementTooLarge, nearEntryLimit, reduce, reviewLoad
        case buildReps, steadyWork, bodyweight

        var guidance: String {
            switch self {
            case .repeatTarget: "Repeat this target and record your working sets."
            case .recoverReserve: "Repeat the same reps and load until you can finish with the intended reps in reserve."
            case .confirmTopSets: "You reached the top of the range on every set. Repeat it once at this load before adding weight."
            case .increase: "Load increased after two sessions at the top of the rep range. Start at the lower end with the new weight."
            case .incrementTooLarge: "Your usual step adds over 10%. Choose a smaller increment in Settings if available, or aim for one more clean rep at this weight."
            case .nearEntryLimit: "Keep this load. The next increment exceeds the app’s weight entry range."
            case .reduce: "Load reduced after repeated sessions below the rep range. Rebuild reps with the lighter weight."
            case .reviewLoad: "You’ve repeatedly missed the rep minimum. Choose a lighter available weight for this lift."
            case .buildReps: "Keep this load. Try adding one rep to a working set while keeping the intended effort."
            case .steadyWork: "Your load and total reps have held steady for four sessions. Check rest and technique, then aim for one extra rep on one set."
            case .bodyweight: "Build reps with consistent form. You can set an added-weight target when you are ready."
            }
        }
    }

    let target: Target
    let reason: Reason

    // Prior exposures are the consecutive, finished sessions in this weekly slot, newest first.
    static func assess(_ current: LiftExposure, previous: [LiftExposure], rule: Rule) -> Self {
        let target = current.target
        func keep(_ reason: Reason) -> Self { Self(target: target, reason: reason) }
        func change(to weight: Double, reason: Reason) -> Self {
            Self(target: Target(weight: weight, repMin: target.repMin, repMax: target.repMax,
                                sets: target.sets, phase: target.phase), reason: reason)
        }

        let increment = rule.equipment == "barbell" ? rule.barbellInc : rule.dbInc
        guard current.complete, target.repMin > 0, target.repMax >= target.repMin,
              increment.isFinite, increment > 0, rule.deloadPct.isFinite,
              (0..<1).contains(rule.deloadPct), rule.missLimit > 0 else { return keep(.repeatTarget) }
        guard let weight = target.weight, weight > 0 else {
            return keep(rule.equipment == "bodyweight" ? .bodyweight : .repeatTarget)
        }
        let comparable = previous.prefix { $0.complete && $0.matchesPrescription(of: current) }
        if current.ready {
            guard comparable.first?.ready == true else { return keep(.confirmTopSets) }
            // Add one available increment to the actual working target, including manually set off-grid loads.
            let next = ((weight + increment) * 1000).rounded() / 1000
            guard next <= 500 else { return keep(.nearEntryLimit) }
            guard next - weight <= weight * 0.10 + 0.0005 else { return keep(.incrementTooLarge) }
            return change(to: next, reason: .increase)
        }
        if current.missedFloor {
            let misses = 1 + comparable.prefix(while: { $0.missedFloor }).count
            guard misses >= rule.missLimit else { return keep(.repeatTarget) }
            let steps = (weight * rule.deloadPct / increment).rounded()
            let reduced = ((weight - steps * increment) * 1000).rounded() / 1000
            guard reduced > 0, reduced < weight else { return keep(.reviewLoad) }
            return change(to: reduced, reason: .reduce)
        }
        guard current.logs.allSatisfy({ ($0.weight ?? 0) + 0.005 >= weight && $0.reps >= target.repMin })
        else { return keep(.repeatTarget) }
        // A top set close to failure calls for recovering reserve before increasing reps or load.
        if current.logs.allSatisfy({ $0.reps >= target.repMax }) { return keep(.recoverReserve) }
        let recent = comparable.prefix(3)
        if recent.count == 3 && recent.allSatisfy({ $0.sameRepsAndLoad(as: current) }) { return keep(.steadyWork) }
        return keep(.buildReps)
    }
}

public func estimate1RM(weight: Double, reps: Int) -> Double {
    epley1RM(weight: weight, reps: reps)
}
