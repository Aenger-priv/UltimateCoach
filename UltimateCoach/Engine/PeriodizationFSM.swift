import Foundation

// Determines phase switch based on simple heuristics derived from requirements.
// Returns "HYP" or "STR".
public func shouldSwitchPhase(
    history: [SetLog],
    currentPhase: String,
    blockStartLoad: Double?,
    currentLoad: Double?
) -> String {
    guard !history.isEmpty else { return currentPhase }
    let assumedRIR = currentPhase == "HYP" ? 2.0 : 1.0
    let avgRIR = history.map { $0.rir ?? assumedRIR }.reduce(0, +) / Double(history.count)
    if currentPhase == "HYP" {
        if let start = blockStartLoad, let curr = currentLoad, start > 0 {
            let gained = (curr - start) / start
            if avgRIR <= 1.0 && gained >= 0.05 {
                return "STR"
            }
        }
        return "HYP"
    } else {
        // STR: if consistent misses or high RIR -> go back to HYP
        if avgRIR > 2.0 { return "HYP" }
        return "STR"
    }
}

