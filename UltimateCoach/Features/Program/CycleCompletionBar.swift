import SwiftUI

struct CycleCompletionBar: View {
    let workouts: CycleDashboardMetrics.Workouts

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(workouts.finishedWorkouts), total: Double(max(1, workouts.totalWorkouts)))
                .tint(CoachStyle.accent)
                .accessibilityHidden(true)
            Text("\(workouts.finishedWorkouts) of \(workouts.totalWorkouts) workouts finished")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(CoachStyle.muted)
        }
        .accessibilityElement(children: .combine)
    }
}
