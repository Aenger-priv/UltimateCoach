import Foundation
import SwiftData

@MainActor
enum WorkoutSession {
    enum SessionError: LocalizedError {
        case alreadyActive, invalidStatus, emptyWorkout, occupiedDate, invalidConditioning, invalidLoad, moveBeforeToday

        var errorDescription: String? {
            switch self {
            case .alreadyActive: "Finish your active workout before starting another."
            case .invalidStatus: "This action is unavailable for the current workout."
            case .emptyWorkout: "Log at least one set or a conditioning result before finishing."
            case .occupiedDate: "There is already a workout on that date."
            case .invalidLoad: "Enter a valid target between 0 and 500 kg, or the equivalent in pounds."
            case .invalidConditioning: "Enter 1–600 minutes and, optionally, 1–500,000 meters."
            case .moveBeforeToday: "Choose a date that keeps upcoming workouts on or after today."
            }
        }
    }

    static func start(_ day: DayPlan, context: ModelContext, now: Date = .now) throws {
        guard day.status == .planned, !day.program.isArchived else { throw SessionError.invalidStatus }
        guard !day.program.days.contains(where: { $0.status == .inProgress }) else { throw SessionError.alreadyActive }
        day.startedAt = now
        try save(context)
    }

    static func finish(_ day: DayPlan, context: ModelContext, now: Date = .now) throws {
        guard day.status == .inProgress else { throw SessionError.invalidStatus }
        guard day.hasResults else { throw SessionError.emptyWorkout }
        day.finishedAt = now
        day.restUntil = nil
        try save(context)
    }

    static func cancelEmpty(_ day: DayPlan, context: ModelContext) throws {
        guard day.status == .inProgress, !day.hasResults else { throw SessionError.invalidStatus }
        day.startedAt = nil
        day.restUntil = nil
        try save(context)
    }

    static func extendRest(_ day: DayPlan, context: ModelContext, now: Date = .now) throws {
        guard day.status == .inProgress, let deadline = day.restUntil, deadline > now else {
            throw SessionError.invalidStatus
        }
        day.restUntil = deadline.addingTimeInterval(30)
        try save(context)
    }

    static func endRest(_ day: DayPlan, context: ModelContext) throws {
        day.restUntil = nil
        try save(context)
    }

    static func skip(_ day: DayPlan, context: ModelContext, now: Date = .now) throws {
        guard !day.program.isArchived, day.status == .planned || day.status == .inProgress, !day.hasResults else {
            throw SessionError.invalidStatus
        }
        day.skippedAt = now
        day.restUntil = nil
        try save(context)
    }

    static func reschedule(_ day: DayPlan, to date: Date, context: ModelContext, calendar: Calendar = .current) throws {
        guard !day.program.isArchived, day.status == .planned, !day.hasResults else { throw SessionError.invalidStatus }
        guard !day.program.days.contains(where: {
            $0 !== day && $0.status != .skipped && $0.date.map { calendar.isDate($0, inSameDayAs: date) } == true
        }) else { throw SessionError.occupiedDate }
        day.date = calendar.startOfDay(for: date)
        try save(context)
    }

    static func suggestedRescheduleDate(for day: DayPlan, now: Date = .now, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        if let date = day.date, date >= today { return date }
        let occupied = Set(day.program.days.filter { $0 !== day && $0.status != .skipped }
            .compactMap { $0.date.map { calendar.startOfDay(for: $0) } })
        var date = today
        while occupied.contains(date), let next = calendar.date(byAdding: .day, value: 1, to: date) {
            date = next
        }
        return date
    }

    static func shiftUpcoming(_ program: Program, to startDate: Date, context: ModelContext,
                              now: Date = .now, calendar: Calendar = .current) throws {
        let newStart = calendar.startOfDay(for: startDate)
        let changes = try upcomingShift(program, to: startDate, now: now, calendar: calendar)
        guard !changes.isEmpty else { return }
        for change in changes { change.day.date = change.newDate }
        program.startDate = newStart
        try save(context)
    }

    struct ScheduleChange: Identifiable {
        let day: DayPlan
        let oldDate: Date
        let newDate: Date

        var id: PersistentIdentifier { day.persistentModelID }
    }

    static func nextUpcomingDate(in program: Program, now: Date = .now, calendar: Calendar = .current) -> Date? {
        upcomingWorkouts(in: program, onOrAfter: calendar.startOfDay(for: now)).compactMap(\.date).min()
    }

    private static func upcomingWorkouts(in program: Program, onOrAfter today: Date) -> [DayPlan] {
        program.days.filter { $0.status == .planned && !$0.hasResults && ($0.date ?? .distantPast) >= today }
    }

    static func upcomingShift(_ program: Program, to startDate: Date, now: Date = .now,
                              calendar: Calendar = .current) throws -> [ScheduleChange] {
        guard !program.isArchived else { throw SessionError.invalidStatus }
        let today = calendar.startOfDay(for: now)
        let newStart = calendar.startOfDay(for: startDate)
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: program.startDate), to: newStart).day ?? 0
        guard offset != 0 else { return [] }
        let movable = upcomingWorkouts(in: program, onOrAfter: today)
        let movableIDs = Set(movable.map(\.persistentModelID))
        var occupied = Set(program.days.filter {
            !movableIDs.contains($0.persistentModelID) && $0.status != .skipped
        }.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })
        var replacements: [ScheduleChange] = []
        for day in movable {
            guard let date = day.date, let shifted = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            guard shifted >= today else { throw SessionError.moveBeforeToday }
            guard occupied.insert(calendar.startOfDay(for: shifted)).inserted else { throw SessionError.occupiedDate }
            replacements.append(ScheduleChange(day: day, oldDate: date, newDate: shifted))
        }
        return replacements.sorted { $0.oldDate < $1.oldDate }
    }

    static func setPlannedLoad(_ exercise: DayExercise, kilograms: Double, context: ModelContext) throws {
        guard !exercise.day.program.isArchived, exercise.day.status == .planned, exercise.logs.isEmpty else { throw SessionError.invalidStatus }
        guard kilograms.isFinite, (0...500.001).contains(kilograms) else { throw SessionError.invalidLoad }
        exercise.targetWeight = kilograms == 0 && exercise.template.equipment == "bodyweight" ? nil : kilograms
        exercise.manualTarget = true
        exercise.targetNote = "You set this target."
        try save(context)
    }

    static func recordConditioning(_ conditioning: Conditioning, minutes: Int, meters: Int?,
                                   context: ModelContext, now: Date = .now) throws {
        guard conditioning.day.status == .inProgress else { throw SessionError.invalidStatus }
        guard (1...600).contains(minutes), meters.map({ (1...500_000).contains($0) }) ?? true else {
            throw SessionError.invalidConditioning
        }
        if conditioning.loggedAt == nil { conditioning.loggedAt = now }
        conditioning.loggedMinutes = minutes
        conditioning.loggedMeters = meters
        try save(context)
    }

    private static func save(_ context: ModelContext) throws {
        do { try context.save() }
        catch {
            context.rollback()
            throw error
        }
    }
}
