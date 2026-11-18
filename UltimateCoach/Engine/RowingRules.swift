import Foundation

// Simple parser for patterns like "6x500m/90s" or "Tabata 8x20/10" or "Zone2 25-30m".
public func nextRowingPrescription(previous: String, success: Bool) -> String {
    guard success else { return previous }
    // Parse duration after the zone label; never replace the zone number itself.
    if previous.lowercased().hasPrefix("zone2 ") {
        let prefix = String(previous.prefix(6))
        let duration = String(previous.dropFirst(6))
        let digits = duration.prefix(while: { $0.isNumber })
        guard let minutes = Int(digits), minutes < 30 else { return previous }
        return prefix + String(min(30, minutes + 2)) + duration.dropFirst(digits.count)
    }

    // Intervals NxDist/Rest -> add one repeat before pace bump
    if let (n, tail) = splitLeadingNumber(before: "x", in: previous), success {
        return "\(n + 1)x\(tail)"
    }
    return previous
}

private func splitLeadingNumber(before token: Character, in s: String) -> (Int, String)? {
    guard let idx = s.firstIndex(of: token) else { return nil }
    let left = String(s[..<idx])
    let right = String(s[s.index(after: idx)...])
    if let n = Int(left.trimmingCharacters(in: .whitespaces)) { return (n, right) }
    return nil
}

