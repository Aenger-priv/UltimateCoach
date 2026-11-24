import SwiftUI

struct CycleDashboard: View {
    @AppStorage("units_kg") private var unitsKg = true
    @Environment(\.dynamicTypeSize) private var typeSize
    let program: Program
    let now: Date

    var body: some View {
        let metrics = CycleDashboardMetrics(program: program, now: now)
        Section("Current cycle") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(program.track?.title ?? "Original program")
                        .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(cycleStage).font(.subheadline).foregroundStyle(CoachStyle.muted)
                        .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                }
                CycleCompletionBar(workouts: metrics.workouts)
            }
            .padding(.vertical, 6)

            metricRow("Schedule adherence", symbol: "calendar.badge.checkmark") {
                if metrics.workouts.scheduledBeforeToday > 0 {
                    Text("\(metrics.workouts.finishedScheduledBeforeToday) of \(metrics.workouts.scheduledBeforeToday) finished · through yesterday")
                } else {
                    Text("Starts after your first scheduled day.")
                }
            }
            metricRow("Recent performance", symbol: "chart.xyaxis.line") {
                if let performance = metrics.performance {
                    Text(performance.name).foregroundStyle(.primary)
                    Text(performance.comparison(useKilograms: unitsKg))
                } else {
                    Text("Finish two comparable workouts with the same lift.")
                }
            }
            NavigationLink("Cycle details") {
                CycleDetailScreen(program: program, now: now)
            }
            .accessibilityIdentifier("cycleDetails")
        }
    }

    private var cycleStage: String {
        if let first = program.days.compactMap(\.date).min(), first > now {
            return "Starts " + first.formatted(date: .abbreviated, time: .omitted)
        }
        switch program.stage(now: now) {
        case .training:
            let today = Calendar.current.startOfDay(for: now)
            let active = program.days.first { $0.status == .inProgress }
            let next = program.days.filter { $0.status == .planned && ($0.date ?? .distantPast) >= today }
                .min { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            if let day = active ?? next {
                let label = active == nil ? "Next workout" : "In progress"
                return day.isDeload ? "\(label) · Deload" : "\(label) · Week \(day.weekIdx) of \(program.trainingWeeks)"
            }
            return "\(program.trainingWeeks) training weeks"
        case .deload: return "Deload week"
        case .readyForNextTrack: return "Ready for the next cycle"
        }
    }

    private func metricRow(_ title: String, symbol: String, @ViewBuilder value: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: symbol)
                    .font(.body.weight(.medium)).foregroundStyle(CoachStyle.accent)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                VStack(alignment: .leading, spacing: 2) { value() }
                    .font(.subheadline).foregroundStyle(CoachStyle.muted)
            }
            .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

extension CycleDashboardMetrics.Performance {
    func comparison(useKilograms: Bool) -> String {
        switch metric {
        case .estimatedMax:
            let previous = WeightUnit.formatted(previousValue, useKilograms: useKilograms)
            let latest = WeightUnit.formatted(latestValue, useKilograms: useKilograms)
            return "Estimated max · \(previous) → \(latest)"
        case .loadAtSameReps:
            let previous = WeightUnit.formatted(previousValue, useKilograms: useKilograms)
            let latest = WeightUnit.formatted(latestValue, useKilograms: useKilograms)
            let load = equipment.lowercased() == "bodyweight" ? " added" : ""
            return "\(previous) → \(latest)\(load)" + (sharedReps.map { " for \($0) reps" } ?? "")
        case .repsAtSameLoad:
            let load = sharedWeight.map { weight in
                WeightUnit.formatted(weight, useKilograms: useKilograms)
                    + (equipment.lowercased() == "bodyweight" ? " added" : "")
            } ?? "bodyweight"
            return "\(Int(previousValue)) → \(Int(latestValue)) reps at \(load)"
        }
    }
}
