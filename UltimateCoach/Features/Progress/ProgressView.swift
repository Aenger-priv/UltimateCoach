import SwiftUI
import SwiftData
import Charts

struct ProgressScreen: View {
    @Query private var days: [DayPlan]
    @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]

    private var history: [DayPlan] {
        days.filter(\.hasResults).sorted { ($0.activityDate ?? .distantPast) > ($1.activityDate ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    ContentUnavailableView("No workouts logged", systemImage: "chart.line.uptrend.xyaxis",
                                           description: Text("Your saved sets and conditioning will appear here."))
                } else {
                    Section("Workout history") {
                        ForEach(history) { day in
                            NavigationLink { WorkoutScreen(day: day) } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(day.isDeload ? "Deload · Day \(day.dayIdx)" : "Week \(day.weekIdx) · Day \(day.dayIdx)")
                                        .font(.headline)
                                    Text(day.program.name).font(.subheadline).foregroundStyle(CoachStyle.muted)
                                    if let date = day.activityDate {
                                        Text(date.formatted(date: .abbreviated, time: .omitted))
                                    }
                                    Text("\(day.loggedSets) sets saved" + (day.conditioning?.loggedMinutes == nil ? "" : " · Conditioning"))
                                        .font(.subheadline).foregroundStyle(CoachStyle.muted)
                                }
                                .padding(.vertical, 5)
                            }
                            .accessibilityIdentifier("historyWorkout_\(day.weekIdx)_\(day.dayIdx)")
                        }
                    }
                    Section("Exercise trends") {
                        ForEach(loggedExercises) { template in
                            NavigationLink {
                                ExerciseTrendScreen(template: template, exercises: exposures(for: template))
                            } label: {
                                Text(template.name).padding(.vertical, 5)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .coachBackground()
            .navigationTitle("Progress")
        }
    }

    private var loggedExercises: [ExerciseTemplate] {
        let logged = Set(history.flatMap(\.exercises).filter { !$0.logs.isEmpty }.map { exerciseKey($0.template) })
        var seen = Set<String>()
        return templates.filter { logged.contains(exerciseKey($0)) && seen.insert(exerciseKey($0)).inserted }
    }

    private func exerciseKey(_ template: ExerciseTemplate) -> String {
        template.name + "|" + template.equipment
    }

    private func exposures(for template: ExerciseTemplate) -> [DayExercise] {
        history.flatMap(\.exercises).filter { exerciseKey($0.template) == exerciseKey(template) && !$0.logs.isEmpty }
    }
}

struct ExerciseTrendScreen: View {
    @AppStorage("units_kg") private var unitsKg = true
    let template: ExerciseTemplate
    let exercises: [DayExercise]

    private struct Sample: Identifiable {
        let id: PersistentIdentifier
        let date: Date
        let value: Double
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(template.name).font(.title.bold()).accessibilityAddTraits(.isHeader)
                if !samples.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Estimated 1RM · \(unitsKg ? "kg" : "lb")")
                            .font(.headline).accessibilityAddTraits(.isHeader)
                        Text("Best estimate per workout from loaded sets of 1–12 reps.")
                            .font(.subheadline).foregroundStyle(CoachStyle.muted)
                        Chart(samples) { sample in
                            LineMark(x: .value("Workout date", sample.date), y: .value("Estimate", sample.value))
                                .foregroundStyle(CoachStyle.accent)
                            PointMark(x: .value("Workout date", sample.date), y: .value("Estimate", sample.value))
                                .foregroundStyle(CoachStyle.accent)
                                .accessibilityLabel(sample.date.formatted(date: .abbreviated, time: .omitted))
                                .accessibilityValue(sample.value.formatted(.number.precision(.fractionLength(0...1))) + (unitsKg ? " kg" : " lb"))
                        }
                        .frame(minHeight: 170)
                        Text("Latest: \(samples.last?.value.formatted(.number.precision(.fractionLength(0...1))) ?? "") \(unitsKg ? "kg" : "lb")")
                            .font(.subheadline.weight(.semibold))
                    }
                    .coachCard()
                }
                Text("Saved sets").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                ForEach(exercises) { exercise in
                    VStack(alignment: .leading, spacing: 7) {
                        if let date = exercise.logs.map(\.timestamp).max() {
                            Text(date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                        }
                        ForEach(exercise.logs.sorted { $0.setIdx < $1.setIdx }) { log in
                            Text("Set \(log.setIdx) · \(log.reps) reps" +
                                 (log.actualWeight.map { $0 > 0 ? " · " + WeightUnit.formatted($0, useKilograms: unitsKg) : "" } ?? ""))
                                .foregroundStyle(CoachStyle.muted)
                        }
                    }
                    .coachCard()
                }
            }
            .coachPage()
        }
        .coachBackground()
        .navigationTitle("Exercise trend")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var samples: [Sample] {
        guard template.equipment != "bodyweight" else { return [] }
        return exercises.compactMap { exercise in
            let estimates = exercise.logs.compactMap { log -> Double? in
                guard let weight = log.actualWeight, weight > 0, (1...12).contains(log.reps) else { return nil }
                return epley1RM(weight: weight, reps: log.reps)
            }
            guard let estimate = estimates.max(), let date = exercise.logs.map(\.timestamp).max() else { return nil }
            return Sample(id: exercise.persistentModelID, date: date, value: WeightUnit.display(estimate, useKilograms: unitsKg))
        }
        .sorted { $0.date < $1.date }
    }
}
