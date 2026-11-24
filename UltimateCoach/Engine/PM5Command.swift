import Foundation

/// Concept2 PM CSAFE Communication Definition, rev. 0.31, tables 5–9 and 19 and pages 88–96.
struct PM5Command {
    let frame: Data
    private let expectedResponse: [UInt8]
    let checksIdleMonitor: Bool

    static let checkMonitor = PM5Command(frame: frame([0x7E, 1, 0x8D]),
                                         expectedResponse: [0x7E, 3, 0x8D, 1, 0], checksIdleMonitor: true)

    static func confirmType(of workout: RowingWorkout) -> PM5Command {
        let type: UInt8
        switch workout {
        case .single(let goal): type = parameters(goal).workoutType
        case .intervals: type = 8
        }
        return PM5Command(frame: frame([0x7E, 1, 0x89]),
                          expectedResponse: [0x7E, 3, 0x89, 1, type], checksIdleMonitor: false)
    }

    static func program(_ workout: RowingWorkout) -> [PM5Command] {
        let prepare: [UInt8] = [0x13, 2, 1, 1]
        let configure: [UInt8] = [0x14, 1, 1]
        switch workout {
        case .single(let goal):
            guard goal.fitsMonitor(interval: false) else { return [] }
            let spec = parameters(goal)
            let split = max(spec.minimumSplit, min(spec.maximumSplit, spec.amount / 5))
            return [configuration([[1, 1, spec.workoutType], duration(3, spec.unit, spec.amount),
                                   duration(5, spec.unit, split), configure, prepare])]

        case let .intervals(count, work, rest):
            guard (2...50).contains(count), (0...595).contains(rest), work.fitsMonitor(interval: true) else { return [] }
            let spec = parameters(work)
            // Variable intervals give the monitor a finite number of efforts and zero rest after the last.
            return (0..<count).map { index in
                let restSeconds = index == count - 1 ? 0 : rest
                var commands: [[UInt8]] = [[0x18, 1, UInt8(index)]]
                if index == 0 { commands.append([1, 1, 8]) }
                commands += [[0x17, 1, spec.intervalType], duration(3, spec.unit, spec.amount),
                             [4, 2, UInt8(restSeconds >> 8), UInt8(truncatingIfNeeded: restSeconds)], configure]
                if index == count - 1 { commands.append(prepare) }
                return configuration(commands)
            }
        }
    }

    enum Response: Equatable { case accepted, busy, invalid }

    func response(to encoded: Data) -> Response {
        guard encoded.count >= 4, encoded.count <= 120, encoded.first == 0xF1, encoded.last == 0xF2 else { return .invalid }
        var contents: [UInt8] = []
        var escaped = false
        for byte in encoded.dropFirst().dropLast() {
            if escaped {
                guard byte <= 3 else { return .invalid }
                contents.append(0xF0 + byte)
                escaped = false
            } else if byte == 0xF3 {
                escaped = true
            } else {
                guard !(0xF0...0xF2).contains(byte) else { return .invalid }
                contents.append(byte)
            }
        }
        guard !escaped, contents.count >= 2, contents.reduce(0, ^) == 0,
              let status = contents.first, status & 0x30 == 0 else { return .invalid }
        let payload = Array(contents.dropFirst().dropLast())
        if checksIdleMonitor, payload.count == expectedResponse.count,
           payload.dropLast().elementsEqual(expectedResponse.dropLast()), payload.last != 0 {
            return .busy
        }
        return payload == expectedResponse ? .accepted : .invalid
    }

    private static func parameters(_ goal: RowingWorkout.Goal)
        -> (amount: Int, unit: UInt8, workoutType: UInt8, intervalType: UInt8, minimumSplit: Int, maximumSplit: Int) {
        switch goal {
        case .time(let seconds): return (seconds * 100, 0x00, 5, 0, 2000, 540_000)
        case .distance(let meters): return (meters, 0x80, 3, 1, 100, 60_000)
        case .calories(let calories): return (calories, 0x40, 10, 6, 5, 65_535)
        }
    }

    private static func duration(_ command: UInt8, _ unit: UInt8, _ amount: Int) -> [UInt8] {
        [command, 5, unit] + [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: amount >> $0) }
    }

    private static func configuration(_ commands: [[UInt8]]) -> PM5Command {
        let body = commands.flatMap { $0 }
        let response = [0x76, UInt8(commands.count)] + commands.compactMap(\.first)
        return PM5Command(frame: frame([0x76, UInt8(body.count)] + body),
                          expectedResponse: response, checksIdleMonitor: false)
    }

    static func frame(_ body: [UInt8]) -> Data {
        var result = Data([0xF1])
        for byte in body + [body.reduce(0, ^)] {
            if (0xF0...0xF3).contains(byte) {
                result.append(contentsOf: [0xF3, byte - 0xF0])
            } else {
                result.append(byte)
            }
        }
        result.append(0xF2)
        return result
    }
}
