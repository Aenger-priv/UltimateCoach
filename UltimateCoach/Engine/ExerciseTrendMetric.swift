import Foundation

nonisolated enum ExerciseTrendMetric: String, CaseIterable, Identifiable {
    case heaviestSet
    case estimatedMax
    case bodyweightReps
    case addedWeight

    var id: Self { self }

    var title: String {
        switch self {
        case .heaviestSet: "Heaviest set"
        case .estimatedMax: "Estimated 1-rep max"
        case .bodyweightReps: "Bodyweight reps"
        case .addedWeight: "Added weight"
        }
    }

    var description: String {
        switch self {
        case .heaviestSet: "The heaviest weight you logged in each workout. Check the reps alongside the weight."
        case .estimatedMax: "Uses sets of 1–10 reps. It’s an estimate from logged reps and varies with how hard the set was."
        case .bodyweightReps: "Your most reps in one set without added weight, for each workout."
        case .addedWeight: "The most weight you added in each workout. Check the reps alongside the weight."
        }
    }

    var isWeight: Bool { self != .bodyweightReps }

    @MainActor
    func value(weight: Double?, reps: Int) -> Double? {
        guard reps > 0, weight.map({ $0.isFinite && $0 >= 0 }) ?? true else { return nil }
        if self == .bodyweightReps {
            return (weight ?? 0) == 0 ? Double(reps) : nil
        }
        guard let weight, weight > 0 else { return nil }
        if self == .estimatedMax {
            guard reps <= 10 else { return nil }
            // A logged single already supplies the observed load.
            return reps == 1 ? weight : epley1RM(weight: weight, reps: reps)
        }
        return weight
    }
}
