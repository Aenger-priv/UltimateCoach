import Foundation

/// Monitor targets are derived from the prescription. Logged results are never used for setup.
enum RowingWorkout: Equatable {
    enum Goal: Equatable {
        case time(seconds: Int)
        case distance(meters: Int)
        case calories(Int)

        var label: String {
            switch self {
            case .time(let seconds):
                return seconds.isMultiple(of: 60) ? "\(seconds / 60) min" : "\(seconds) sec"
            case .distance(let meters): return "\(meters.formatted()) m"
            case .calories(let calories): return "\(calories) Cal"
            }
        }

        func fitsMonitor(interval: Bool) -> Bool {
            switch self {
            case .time(let seconds): return (20...35_999).contains(seconds)
            case .distance(let meters): return (100...999_999).contains(meters)
            case .calories(let calories): return (5...(interval ? 999 : 65_535)).contains(calories)
            }
        }
    }

    case single(Goal)
    case intervals(count: Int, work: Goal, restSeconds: Int)

    var summary: String {
        switch self {
        case .single(let target): return target.label
        case let .intervals(count, work, restSeconds):
            return "\(count) × \(work.label) · \(restSeconds) sec rest between efforts"
        }
    }

    var manualMode: String {
        let goal: Goal
        switch self {
        case .single(let target): goal = target
        case .intervals: return "Variable intervals"
        }
        switch goal {
        case .time: return "Single time"
        case .distance: return "Single distance"
        case .calories: return "Single calorie"
        }
    }
}

struct RowingPrescription: Equatable {
    let workout: RowingWorkout
    let minuteRange: ClosedRange<Int>?

    init?(_ text: String) {
        let value = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "×", with: "x")
        minuteRange = Self.minutes(in: value)
        if let minuteRange {
            workout = .single(.time(seconds: minuteRange.lowerBound * 60))
        } else if let match = value.wholeMatch(of: /tabata (\d+)x(\d+)\/(\d+)/),
                  let count = Int(match.1), let seconds = Int(match.2), let rest = Int(match.3),
                  let result = Self.intervals(count, .time(seconds: seconds), rest) {
            workout = result
        } else if let match = value.wholeMatch(of: /(\d+)\s*x\s*(\d+)\s*(m|s|cal)\s*\/\s*(\d+)\s*s/),
                  let count = Int(match.1), let amount = Int(match.2), let rest = Int(match.4),
                  let result = Self.intervals(count, Self.goal(amount, match.3), rest) {
            workout = result
        } else if let match = value.wholeMatch(of: /(\d+)\s*(m|s|cal|calories|meters|metres|seconds|minutes|min)/),
                  let amount = Int(match.1), amount <= 999_999 {
            let target = Self.goal(amount, match.2)
            guard target.fitsMonitor(interval: false) else { return nil }
            workout = .single(target)
        } else {
            return nil
        }
    }

    func workout(minutes: Int) -> RowingWorkout {
        guard let minuteRange, minuteRange.contains(minutes) else { return workout }
        return .single(.time(seconds: minutes * 60))
    }

    private static func minutes(in text: String) -> ClosedRange<Int>? {
        let match = text.wholeMatch(of: /(?:easy row · |zone2 )(\d+)(?:-(\d+))?\s*(?:m|minutes)/)
        let progressive = text.wholeMatch(of: /(\d+)m progressive/)
        guard let lowText = match?.1 ?? progressive?.1, let low = Int(lowText) else { return nil }
        let high = match?.2.map { Int($0) } ?? low
        guard let high, low >= 1, high >= low, high <= 599 else { return nil }
        return low...high
    }

    private static func intervals(_ count: Int, _ work: RowingWorkout.Goal, _ rest: Int) -> RowingWorkout? {
        guard (2...50).contains(count), work.fitsMonitor(interval: true), (0...595).contains(rest) else { return nil }
        return .intervals(count: count, work: work, restSeconds: rest)
    }

    private static func goal(_ value: Int, _ unit: Substring) -> RowingWorkout.Goal {
        switch unit {
        case "m", "meters", "metres": .distance(meters: value)
        case "cal", "calories": .calories(value)
        case "min", "minutes": .time(seconds: value * 60)
        default: .time(seconds: value)
        }
    }
}
