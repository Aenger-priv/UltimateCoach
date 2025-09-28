import XCTest
import SwiftData
@testable import UltimateCoach

final class SeedDataTests: XCTestCase {
    func testSeedLoadsProgram() async throws {
        let container = try ModelContainer(for: Program.self, DayPlan.self, ExerciseTemplate.self, DayExercise.self, ExerciseLog.self, ProgressionRule.self, PhaseState.self, Conditioning.self)
        await SeedData.seedIfNeeded(context: container.mainContext)
        let count = try container.mainContext.fetchCount(FetchDescriptor<Program>())
        XCTAssertGreaterThan(count, 0)
        let days = try container.mainContext.fetch(FetchDescriptor<DayPlan>())
        XCTAssertFalse(days.isEmpty)
        XCTAssertNotNil(days.first?.date)
    }
}
