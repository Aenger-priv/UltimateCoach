import SwiftUI
import SwiftData
import Charts

struct ExerciseTrendScreen: View {
    @AppStorage("units_kg") private var unitsKg = true
    @State private var metric: ExerciseTrendMetric
    let group: ExerciseTrendGroup

    init(group: ExerciseTrendGroup) {
        self.group = group
        _metric = State(initialValue: group.initialMetric)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(group.id.name).font(.title.bold()).accessibilityAddTraits(.isHeader)
                trendCard
                Text("Saved sets").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                ForEach(group.sessions) { session in
                    sessionCard(session)
                }
            }
            .coachPage()
        }
        .coachBackground()
        .navigationTitle("Exercise trend")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trendCard: some View {
        let points = group.points(for: metric)
        return VStack(alignment: .leading, spacing: 12) {
            Menu {
                Picker("Trend metric", selection: $metric) {
                    ForEach(group.metrics) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
            } label: {
                Label(metric.title, systemImage: "chevron.up.chevron.down")
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityLabel("Trend metric")
            .accessibilityValue(metric.title)
            .accessibilityIdentifier("exerciseTrendMetric")

            Text(metric.description).font(.subheadline).foregroundStyle(CoachStyle.muted)
            if points.count >= 2 {
                trendChart(points)
            }
            if let latest = points.last {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest · \(display(latest.value))").font(.headline)
                        .accessibilityIdentifier("latestTrendValue")
                    Text(latest.date.formatted(date: .abbreviated, time: .omitted) + " · " +
                         (latest.session.day.program.track ?? .hypertrophy).title)
                    if metric.isWeight { Text("From \(setSummary(latest.log))") }
                }
                .font(.subheadline).foregroundStyle(CoachStyle.muted)
            }
            if points.count == 1 {
                Text("Log another qualifying workout to see a trend.")
                    .font(.subheadline).foregroundStyle(CoachStyle.muted)
            } else if points.isEmpty {
                Text("No qualifying sets yet.").font(.subheadline).foregroundStyle(CoachStyle.muted)
            }
            Text("Charts exclude deload workouts. You can review those sets below.")
                .font(.footnote).foregroundStyle(CoachStyle.muted)
        }
        .coachCard()
    }

    private func trendChart(_ points: [ExerciseTrendGroup.Point]) -> some View {
        let unit = metric.isWeight ? (unitsKg ? "kg" : "lb") : "reps"
        return Chart(points) { point in
            LineMark(x: .value("Workout date", point.date),
                     y: .value(metric.title, plottedValue(point.value)))
                .foregroundStyle(CoachStyle.accent)
                .accessibilityHidden(true)
            PointMark(x: .value("Workout date", point.date),
                      y: .value(metric.title, plottedValue(point.value)))
                .foregroundStyle(CoachStyle.accent)
                .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue(display(point.value))
        }
        .chartXScale(domain: dateDomain(points))
        .chartYScale(domain: valueDomain(points))
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
        .chartYAxisLabel(unit, position: .topLeading)
        .accessibilityLabel(metric.title)
        .frame(height: 205)
    }

    private func dateDomain(_ points: [ExerciseTrendGroup.Point]) -> ClosedRange<Date> {
        guard let first = points.first?.date, let last = points.last?.date else { return .distantPast ... .now }
        let padding = max(3600, last.timeIntervalSince(first) * 0.04)
        return first.addingTimeInterval(-padding) ... last.addingTimeInterval(padding)
    }

    private func valueDomain(_ points: [ExerciseTrendGroup.Point]) -> ClosedRange<Double> {
        let values = points.map { plottedValue($0.value) }
        let high = values.max() ?? 1
        let low = values.min() ?? 0
        let padding = max(metric.isWeight ? 2 : 1, (high - low) * 0.2, high * 0.08)
        return max(0, low - padding) ... (high + padding)
    }

    private func sessionCard(_ session: ExerciseTrendGroup.Session) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if let date = session.lastSetAt {
                Text(date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
            }
            Text(session.sessionSubtitle).font(.subheadline).foregroundStyle(CoachStyle.muted)
            ForEach(session.exercises) { exercise in
                ForEach(exercise.logs.sorted { $0.setIdx < $1.setIdx }) { log in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set \(log.setIdx) · " + setSummary(log))
                        if let reserve = log.rir {
                            Text("\(reserve.formatted()) reps in reserve").font(.footnote)
                        }
                    }
                    .foregroundStyle(CoachStyle.muted)
                }
            }
        }
        .coachCard()
    }

    private func setSummary(_ log: ExerciseLog) -> String {
        let reps = "\(log.reps) reps"
        if let weight = log.actualWeight, weight > 0 {
            let load = WeightUnit.formatted(weight, useKilograms: unitsKg)
            return load + (group.id.equipment.lowercased() == "bodyweight" ? " added" : "") + " × " + reps
        }
        return reps
    }

    private func display(_ value: Double) -> String {
        metric.isWeight ? WeightUnit.formatted(value, useKilograms: unitsKg) : "\(Int(value)) reps"
    }

    private func plottedValue(_ value: Double) -> Double {
        metric.isWeight ? WeightUnit.display(value, useKilograms: unitsKg) : value
    }
}

private extension ExerciseTrendGroup.Session {
    var sessionSubtitle: String {
        let track = (day.program.track ?? .hypertrophy).title
        if day.isDeload { return track + " · Deload" }
        if day.status == .inProgress { return track + " · In progress" }
        return track
    }
}
