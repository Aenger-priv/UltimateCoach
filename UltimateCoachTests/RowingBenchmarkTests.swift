import Foundation
import XCTest
@testable import UltimateCoach

@MainActor
final class RowingBenchmarkTests: XCTestCase {
    func testLatestMatchedRowUsesTwoMostRecentDistancesInThatPrescription() throws {
        let program = Program(name: "Cycle", startDate: .now, totalWeeks: 13)
        program.deloadWeek = 13
        func add(week: Int, slot: Int = 1, text: String = "Easy row · 15–20 minutes",
                 minutes: Int = 15, meters: Int?, finished: Bool = true) {
            let day = DayPlan(program: program, weekIdx: week, dayIdx: slot)
            let date = Date(timeIntervalSinceReferenceDate: Double(week * 7 + slot) * 86_400)
            day.finishedAt = finished ? date : nil
            let row = Conditioning(day: day, type: "row", protocolText: text)
            row.loggedMinutes = minutes
            row.loggedMeters = meters
            day.conditioning = row
            if !program.days.contains(where: { $0 === day }) { program.days.append(day) }
        }
        add(week: 1, meters: 2500)
        add(week: 2, meters: 2600)
        add(week: 3, meters: 2800)
        add(week: 4, minutes: 20, meters: 3500)
        add(week: 5, meters: nil)
        add(week: 6, slot: 4, meters: 2900)
        add(week: 7, text: "6x500m/90s", meters: 3000)
        add(week: 8, text: "6x500m/90s", meters: 3200)
        add(week: 9, meters: 3100, finished: false)
        add(week: 13, meters: 2300)
        let comparison = try XCTUnwrap(RowingBenchmark.latest(in: program))
        XCTAssertEqual(comparison.minutes, 15)
        XCTAssertEqual(comparison.previousMeters, 2600)
        XCTAssertEqual(comparison.latestMeters, 2800)
    }
}
