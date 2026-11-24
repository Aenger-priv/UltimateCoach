import Foundation

/// The randomized action is highlighting the existing +30s button. Either arm can use it.
enum AdaptiveRest {
    struct Observation {
        let offered: Bool
        let metTarget: Bool
    }

    // Per-arm ridge estimates on one-hot context (first rest or later rest), shrunk toward 0.5.
    // Start with the simple hard-set cue. Retain random assignment in both directions.
    static func offerProbability(for history: [Observation]) -> Double {
        let offered = history.filter(\.offered)
        let usual = history.filter { !$0.offered }
        guard offered.count >= 4, usual.count >= 4 else { return 0.5 }
        func estimate(_ observations: [Observation]) -> Double {
            (1 + Double(observations.count { $0.metTarget })) / (2 + Double(observations.count))
        }
        // A numerical tie at the ten-point margin favors the ordinary timer.
        return estimate(offered) - estimate(usual) > 0.1 + 1e-12 ? 0.85 : 0.15
    }

    static func selectOffer(probability: Double, draw: Double) -> Bool { draw < probability }

    static func assign(after log: ExerciseLog, draw: Double) {
        let lift = log.dayExercise
        guard log.restOffered == nil, !lift.day.isDeload, lift.restSeconds > 0, log.setIdx < lift.sets,
              let target = lift.targetWeight, target > 0,
              abs((log.actualWeight ?? 0) - target) < 0.005 else { return }
        let previous = lift.logs.first { $0.setIdx == log.setIdx - 1 }
        let repsDropped = previous.map {
            abs(($0.actualWeight ?? 0) - target) < 0.005 && $0.reps > log.reps
        } ?? false
        guard repsDropped || log.reps < lift.targetRepsMin || log.rir.map({ $0 <= 2 }) == true else { return }
        let history = observations(for: lift, afterFirstSet: log.setIdx == 1, asOf: log.timestamp)
        let probability = offerProbability(for: history)
        log.restOfferProbability = probability
        log.restOffered = selectOffer(probability: probability, draw: draw)
    }

    static func linkFollowUp(_ log: ExerciseLog, previous: ExerciseLog?) {
        guard let previous, previous.restOffered != nil, previous.dayExercise === log.dayExercise,
              previous.setIdx + 1 == log.setIdx,
              (10...900).contains(log.timestamp.timeIntervalSince(previous.timestamp)) else { return }
        log.restFollowUp = true
    }

    static func observations(for lift: DayExercise, afterFirstSet: Bool, asOf date: Date) -> [Observation] {
        var history: [Observation] = []
        for day in lift.day.program.days where !day.isDeload && day.startedAt != nil {
            for exercise in day.exercises where exercise.phase == lift.phase {
                let sets = exercise.logs.sorted { $0.setIdx < $1.setIdx }
                for (prior, next) in zip(sets, sets.dropFirst()) {
                    guard let offered = prior.restOffered, next.restFollowUp == true,
                          next.timestamp <= date, (prior.setIdx == 1) == afterFirstSet,
                          let weight = exercise.targetWeight, let performed = next.actualWeight else { continue }
                    let reserve = day.program.track == nil && exercise.phase == "STR" ? 1.0 : 2.0
                    let metTarget = performed + 0.005 >= weight && next.reps >= exercise.targetRepsMin &&
                        (next.rir.map { $0 >= reserve } ?? true)
                    history.append(Observation(offered: offered, metTarget: metTarget))
                }
            }
        }
        return history
    }
}
