import XCTest
@testable import UltimateCoach

@MainActor
final class PullupRulesTests: XCTestCase {
    func testAddWeightWhenVolumeHigh() throws {
        let logs = [SetLog(weight: nil, reps: 10, rir: 2), SetLog(weight: nil, reps: 8, rir: 2), SetLog(weight: nil, reps: 8, rir: 2), SetLog(weight: nil, reps: 8, rir: 2)]
        let result = aggregatePullupVolume(logs: logs)
        XCTAssertEqual(result.suggestedWeightDelta, 2.5)
    }

    func testReduceWeightWhenWeightedAndLowTotal() throws {
        let logs = [SetLog(weight: 5, reps: 5, rir: 3), SetLog(weight: 5, reps: 5, rir: 3), SetLog(weight: 5, reps: 5, rir: 3), SetLog(weight: 5, reps: 4, rir: 3)]
        let result = aggregatePullupVolume(logs: logs)
        XCTAssertEqual(result.suggestedWeightDelta, -2.5)
    }
}


extension PullupRulesTests {
    func testModerateBodyweightVolumeHoldsLoad() {
        XCTAssertEqual(aggregatePullupVolume(logs: [SetLog(weight: nil, reps: 8, rir: 2)]).suggestedWeightDelta, 0)
    }
}
