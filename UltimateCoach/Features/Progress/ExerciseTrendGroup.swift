import Foundation
import SwiftData

struct ExerciseTrendGroup: Identifiable {
    struct Key: Hashable {
        let name: String
        let equipment: String
    }

    struct Session: Identifiable {
        let day: DayPlan
        let exercises: [DayExercise]

        var id: PersistentIdentifier { day.persistentModelID }
        var logs: [ExerciseLog] { exercises.flatMap(\.logs) }
        var lastSetAt: Date? { logs.map(\.timestamp).max() }
    }

    struct Point: Identifiable {
        let session: Session
        let log: ExerciseLog
        let value: Double

        var id: PersistentIdentifier { session.id }
        var date: Date { log.timestamp }
    }

    let id: Key
    let sessions: [Session]

    var metrics: [ExerciseTrendMetric] {
        id.equipment.lowercased() == "bodyweight" ? [.bodyweightReps, .addedWeight] : [.heaviestSet, .estimatedMax]
    }

    var initialMetric: ExerciseTrendMetric {
        if id.equipment.lowercased() != "bodyweight" { return .heaviestSet }
        return points(for: .bodyweightReps).isEmpty && !points(for: .addedWeight).isEmpty
            ? .addedWeight : .bodyweightReps
    }

    static func collect(from days: [DayPlan]) -> [ExerciseTrendGroup] {
        var groups: [Key: [Session]] = [:]
        for day in days {
            let exercisesByMovement = Dictionary(grouping: day.exercises.filter { !$0.logs.isEmpty }) { exercise in
                Key(name: exercise.template.name, equipment: exercise.template.equipment)
            }
            for (key, exercises) in exercisesByMovement {
                groups[key, default: []].append(Session(day: day, exercises: exercises.sorted { $0.orderIdx < $1.orderIdx }))
            }
        }
        return groups.map { key, sessions in
            ExerciseTrendGroup(id: key, sessions: sessions.sorted { ($0.lastSetAt ?? .distantPast) > ($1.lastSetAt ?? .distantPast) })
        }
        .sorted { ($0.id.name.lowercased(), $0.id.equipment) < ($1.id.name.lowercased(), $1.id.equipment) }
    }

    func points(for metric: ExerciseTrendMetric) -> [Point] {
        sessions.filter { !$0.day.isDeload }.compactMap { session in
            session.logs.compactMap { log in
                metric.value(weight: log.actualWeight, reps: log.reps).map { Point(session: session, log: log, value: $0) }
            }
            .max { ($0.value, $0.log.reps, $0.date) < ($1.value, $1.log.reps, $1.date) }
        }
        .sorted { ($0.date, $0.value) < ($1.date, $1.value) }
    }
}
