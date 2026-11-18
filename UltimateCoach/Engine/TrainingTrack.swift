import Foundation

enum TrainingTrack: String, Codable, CaseIterable, Identifiable {
    case hypertrophy, strength

    var id: Self { self }
    var title: String { self == .hypertrophy ? "Hypertrophy" : "Strength" }
    var phase: String { self == .hypertrophy ? "HYP" : "STR" }
    var alternate: Self { self == .hypertrophy ? .strength : .hypertrophy }
    var summary: String {
        switch self {
        case .hypertrophy: "Build muscle with more weekly sets, mostly in the 6–15 rep range."
        case .strength: "Practice heavier bench presses, squats and deadlifts, with lighter assistance work."
        }
    }
}
