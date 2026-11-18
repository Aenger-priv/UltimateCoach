import SwiftUI
import SwiftData

struct ProgressScreen: View {
    @Query private var days: [DayPlan]

    var body: some View {
        NavigationStack {
            List {
                let history = days.filter(\.hasResults).sorted {
                    ($0.activityDate ?? .distantPast) > ($1.activityDate ?? .distantPast)
                }
                if history.isEmpty {
                    ContentUnavailableView("No workouts logged", systemImage: "chart.line.uptrend.xyaxis",
                                           description: Text("Your saved sets and conditioning will appear here."))
                } else {
                    let groups = ExerciseTrendGroup.collect(from: history)
                    if !groups.isEmpty {
                        Section("Exercise trends") {
                            ForEach(groups) { group in
                                NavigationLink {
                                    ExerciseTrendScreen(group: group)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.id.name).font(.headline)
                                        Text(group.id.equipment.capitalized)
                                            .font(.subheadline).foregroundStyle(CoachStyle.muted)
                                    }
                                    .padding(.vertical, 5)
                                }
                                .accessibilityIdentifier("exerciseTrend_\(group.id.name)_\(group.id.equipment)")
                            }
                        }
                    }
                    Section("Workout history") {
                        ForEach(history) { day in
                            NavigationLink { WorkoutScreen(day: day) } label: { historyRow(day) }
                                .accessibilityIdentifier("historyWorkout_\(day.weekIdx)_\(day.dayIdx)")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .coachBackground()
            .navigationTitle("Progress")
        }
    }

    private func historyRow(_ day: DayPlan) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(day.isDeload ? "Deload · Day \(day.dayIdx)" : "Week \(day.weekIdx) · Day \(day.dayIdx)")
                .font(.headline)
            Text((day.program.track ?? .hypertrophy).title + " · " + historyStatus(day))
                .font(.subheadline).foregroundStyle(CoachStyle.muted)
            if let date = day.activityDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
            }
            if day.loggedSets > 0 {
                Text(day.loggedSets == 1 ? "1 set saved" : "\(day.loggedSets) sets saved")
                    .font(.subheadline).foregroundStyle(CoachStyle.muted)
            }
            if let minutes = day.conditioning?.loggedMinutes {
                Text("Conditioning · \(minutes) min").font(.subheadline).foregroundStyle(CoachStyle.muted)
            }
        }
        .padding(.vertical, 5)
    }

    private func historyStatus(_ day: DayPlan) -> String {
        switch day.status {
        case .inProgress: "In progress"
        case .finished: "Finished"
        case .planned, .skipped: "Saved activity"
        }
    }
}
