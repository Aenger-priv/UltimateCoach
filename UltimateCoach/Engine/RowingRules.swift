import Foundation

// Simple parser for patterns like "6x500m/90s" or "Tabata 8x20/10" or "Zone2 25-30m".
public func nextRowingPrescription(previous: String, success: Bool) -> String {
    // If Zone 2, progress duration up to 30m
    if previous.lowercased().contains("zone") {
        if let minutes = extractFirstInt(previous) {
            if minutes < 30 {
                return previous.replacingOccurrences(of: "\(minutes)", with: "\(min(30, minutes + 2))")
            }
        }
        return previous
    }

    // Intervals NxDist/Rest -> add one repeat before pace bump
    if let (n, tail) = splitLeadingNumber(before: "x", in: previous), success {
        return "\(n + 1)x\(tail)"
    }
    return previous
}

private func extractFirstInt(_ s: String) -> Int? {
    let nums = s.split(whereSeparator: { !$0.isNumber })
    return nums.first.flatMap { Int($0) }
}

private func splitLeadingNumber(before token: Character, in s: String) -> (Int, String)? {
    guard let idx = s.firstIndex(of: token) else { return nil }
    let left = String(s[..<idx])
    let right = String(s[s.index(after: idx)...])
    if let n = Int(left.trimmingCharacters(in: .whitespaces)) { return (n, right) }
    return nil
}

