import SwiftUI

struct CycleDetailScreen: View {
    @AppStorage("units_kg") private var unitsKg = true
    let program: Program
    let now: Date

    var body: some View {
        let metrics = CycleDashboardMetrics(program: program, now: now)
        List {
            Section {
                if metrics.workouts.scheduledBeforeToday == 0 {
                    Text("Your first scheduled workout enters this summary the following day.")
                } else {
                    measurement("Workouts finished",
                                value: "\(metrics.workouts.finishedScheduledBeforeToday) of \(metrics.workouts.scheduledBeforeToday)")
                    if metrics.plannedSetsScheduledBeforeToday > 0 {
                        measurement("Prescribed sets logged",
                                    value: "\(metrics.loggedSetsScheduledBeforeToday) of \(metrics.plannedSetsScheduledBeforeToday)")
                    }
                }
            } header: {
                Text("Adherence through yesterday")
            } footer: {
                Text("Uses your current schedule, including skipped workouts and deloads. Finishing a partial workout counts as a visit. Saved sets show how much lifting you completed.")
            }

            Section("Lift comparison") {
                if let performance = metrics.performance {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(performance.name).font(.headline)
                        Text(performance.comparison(useKilograms: unitsKg))
                            .font(.body.weight(.medium)).monospacedDigit()
                        Text(performance.previousDate.formatted(date: .abbreviated, time: .omitted)
                             + " → " + performance.latestDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline).foregroundStyle(CoachStyle.muted)
                    }
                    .padding(.vertical, 3)
                    Text(performance.metric == .estimatedMax
                         ? "These are estimates from your best weighted sets of 1–10 reps. Differences in effort can move the estimate."
                         : "These sets share a weight or a rep count. Similar technique and effort make the comparison more meaningful.")
                        .font(.subheadline).foregroundStyle(CoachStyle.muted)
                } else {
                    Text("A comparison appears once you finish two comparable sessions for a lift in the same workout slot this cycle. Deloads are excluded.")
                        .foregroundStyle(CoachStyle.muted)
                }
            }

            if let row = RowingBenchmark.latest(in: program) {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(row.minutes)-minute row").font(.headline)
                        Text("\(row.previousMeters.formatted()) m → \(row.latestMeters.formatted()) m")
                            .font(.body.weight(.medium)).monospacedDigit()
                        Text(row.previousDate.formatted(date: .abbreviated, time: .omitted)
                             + " → " + row.latestDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline).foregroundStyle(CoachStyle.muted)
                    }
                } header: {
                    Text("Rowing distance")
                } footer: {
                    Text("Two rows with the same prescription and logged minutes. Similar effort makes the distances easier to compare.")
                }
            }

            Section {
                guidance("Pick a smaller milestone",
                         "Keep the weight steady and aim for one more clean rep within the prescribed range. Compare the same exercise with similar rest and effort.")
                guidance("If performance keeps falling",
                         "Review missed sets and recovery. Use a lighter target if needed, then build back through the rep range.")
                guidance("Choose the next emphasis",
                         "Maintaining a lift is a valid goal. For a different challenge after the deload, Strength emphasizes heavier lifts and Hypertrophy gives you more weekly sets.")
            } header: {
                Text("When a lift levels off")
            } footer: {
                Text("Workout logs show what you have achieved. They cannot estimate how much lifetime strength or muscle growth you have left.")
            }
        }
        .scrollContentBackground(.hidden)
        .coachBackground()
        .navigationTitle("Cycle details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func measurement(_ name: String, value: String) -> some View {
        LabeledContent(name) { Text(value).bold().monospacedDigit() }
    }

    private func guidance(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text).font(.subheadline).foregroundStyle(CoachStyle.muted)
        }
        .padding(.vertical, 4)
    }
}
