import Foundation
import SwiftData

@Model
final class Program {
    var name: String
    var startDate: Date
    var totalWeeks: Int
    var trackCode: String?
    var deloadWeek: Int?
    var archivedAt: Date?

    var track: TrainingTrack? { trackCode.flatMap(TrainingTrack.init(rawValue:)) }
    var isArchived: Bool { archivedAt != nil }
    var trainingWeeks: Int { deloadWeek.map { $0 - 1 } ?? totalWeeks }

    static func latestArchived(in programs: [Program]) -> Program? {
        programs.filter(\.isArchived).max {
            ($0.archivedAt ?? .distantPast, $0.startDate) < ($1.archivedAt ?? .distantPast, $1.startDate)
        }
    }

    func nextStartDate(calendar: Calendar = .current) -> Date {
        let scheduledEnd = calendar.date(byAdding: .day, value: totalWeeks * 7, to: startDate) ?? startDate
        let lastPlannedDate = days.filter { $0.status == .planned }.compactMap(\.date).max()
        let latestWorkoutEnd = lastPlannedDate.flatMap { calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0)) }
        let recoveryEnd = days.filter(\.isDeload).compactMap(\.date).min()
            .flatMap { calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: $0)) }
        return max(scheduledEnd, latestWorkoutEnd ?? scheduledEnd, recoveryEnd ?? scheduledEnd)
    }

    func stage(now: Date, calendar: Calendar = .current) -> TrainingCycle.Stage {
        TrainingCycle.stage(on: now, trainingEnds: calendar.date(byAdding: .day, value: trainingWeeks * 7, to: startDate) ?? startDate,
                            cycleEnds: nextStartDate(calendar: calendar), hasDeload: deloadWeek != nil,
                            hasActiveWorkout: days.contains { $0.status == .inProgress })
    }
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
    var isDeload: Bool { weekIdx == program.deloadWeek }
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
