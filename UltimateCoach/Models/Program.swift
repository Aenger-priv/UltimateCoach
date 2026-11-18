import Foundation
import SwiftData

@Model
final class Program {
    var name: String
    var startDate: Date
    var totalWeeks: Int
    @Relationship(deleteRule: .cascade) var days: [DayPlan]

    init(name: String, startDate: Date, totalWeeks: Int) {
        self.name = name
        self.startDate = startDate
        self.totalWeeks = totalWeeks
        self.days = []
    }
}

@Model
final class DayPlan {
    var program: Program
    var weekIdx: Int
    var dayIdx: Int
    var date: Date?
    @Relationship(deleteRule: .cascade) var exercises: [DayExercise]
    var conditioning: Conditioning?
    var startedAt: Date?
    var finishedAt: Date?
    var skippedAt: Date?
    var restUntil: Date?

    var loggedSets: Int { exercises.reduce(0) { $0 + $1.logs.count } }
    var plannedSets: Int { exercises.reduce(0) { $0 + $1.sets } }
    var hasResults: Bool { loggedSets > 0 || conditioning?.loggedMinutes != nil }
    var activityDate: Date? {
        finishedAt ?? (exercises.flatMap(\.logs).map(\.timestamp) + [conditioning?.loggedAt].compactMap { $0 }).max()
    }
    var status: WorkoutStatus {
        if skippedAt != nil { return .skipped }
        if finishedAt != nil { return .finished }
        if startedAt != nil { return .inProgress }
        return .planned
    }

    init(program: Program, weekIdx: Int, dayIdx: Int) {
        self.program = program
        self.weekIdx = weekIdx
        self.dayIdx = dayIdx
        self.exercises = []
    }
}


enum WorkoutStatus: String {
    case planned = "Planned"
    case inProgress = "In progress"
    case finished = "Finished"
    case skipped = "Skipped"
}
