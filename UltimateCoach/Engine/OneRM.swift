import Foundation

// Epley estimate 1RM: w * (1 + reps/30)
public func epley1RM(weight: Double, reps: Int) -> Double {
    guard weight > 0, reps >= 1 else { return 0 }
    return weight * (1.0 + Double(reps) / 30.0)
}

