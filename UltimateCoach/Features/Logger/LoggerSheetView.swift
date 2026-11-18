import SwiftUI
import SwiftData

struct LoggerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @AppStorage("units_kg") private var unitsKg = true
    @AppStorage("barbell_inc") private var barbellInc = 2.5
    @AppStorage("db_inc") private var dbInc = 2.0
    @AppStorage("enable_rir") private var enableRIR = true
    let exercise: DayExercise
    @State private var weightText = ""
    @State private var reps = 8
    @State private var rir = 2.0
    @State private var recordEffort = false
    @State private var nextTarget: Target?
    @State private var errorMessage: String?
    @State private var editing: ExerciseLog?
    @State private var scrollTarget: String?
    @FocusState private var weightFocused: Bool

    private var canLog: Bool { exercise.day.status == .inProgress && exercise.logs.count < exercise.sets }
    private var increment: Double { exercise.template.equipment == "barbell" ? barbellInc : dbInc }
    private var sortedLogs: [ExerciseLog] { exercise.logs.sorted { $0.setIdx < $1.setIdx } }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    content
                }
                .onChange(of: scrollTarget) { _, target in
                    if let target { proxy.scrollTo(target, anchor: .top) }
                    scrollTarget = nil
                }
            }
            .coachBackground()
            .navigationTitle("Set log")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
            .alert("Could not save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onAppear { fill(from: sortedLogs.last) }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Text(exercise.template.name).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text("Target").font(.subheadline.weight(.semibold)).foregroundStyle(CoachStyle.accent)
                Text("\(exercise.sets) sets of \(exercise.targetRepsMin)–\(exercise.targetRepsMax) reps")
                Text(exercise.targetWeight.map { WeightUnit.formatted($0, useKilograms: unitsKg) } ?? "Bodyweight")
                    .foregroundStyle(CoachStyle.muted)
                    .font(.subheadline)
            }
            .coachCard()

            if canLog || editing != nil { entry.id("setEntry") }
            if exercise.logs.count >= exercise.sets, editing == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Label("All \(exercise.sets) sets saved", systemImage: "checkmark.circle.fill")
                        .font(.headline).foregroundStyle(CoachStyle.accent)
                    if let target = nextTarget {
                        Text("Next target: \(target.repMin)–\(target.repMax) reps" +
                             (target.weight.map { " · " + WeightUnit.formatted($0, useKilograms: unitsKg) } ?? ""))
                    }
                }
                .coachCard()
            }
            if exercise.day.status == .inProgress, let deadline = exercise.day.restUntil {
                RestTimer(deadline: deadline, onClear: clearTimer).coachCard()
            }
            if !sortedLogs.isEmpty { savedSets.id("savedSets") }
        }
        .coachPage()
    }

    @ViewBuilder
    private var saveBar: some View {
        if canLog || editing != nil {
            Button(editing == nil ? "Save set \(exercise.logs.count + 1)" : "Save changes", systemImage: "checkmark") {
                saveSet()
            }
            .buttonStyle(CoachActionStyle())
            .accessibilityIdentifier("saveSet")
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: 656)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    private var entry: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(editing.map { "Editing set \($0.setIdx)" } ?? "Set \(exercise.logs.count + 1) of \(exercise.sets)")
                .font(.headline).accessibilityAddTraits(.isHeader)
            Text(exercise.targetWeight == nil ? "Added weight" : "Weight")
                .font(.subheadline.weight(.semibold))
            HStack {
                TextField("Weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($weightFocused)
                    .accessibilityLabel(unitsKg ? "Weight in kilograms" : "Weight in pounds")
                    .accessibilityIdentifier("weightInput")
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                Text(unitsKg ? "kg" : "lb").foregroundStyle(CoachStyle.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            Stepper {
                Text("Adjust by \(WeightUnit.formatted(increment, useKilograms: unitsKg))")
                    .fixedSize(horizontal: false, vertical: true)
            } onIncrement: { adjustWeight(by: increment) }
              onDecrement: { adjustWeight(by: -increment) }
            Divider()
            Stepper(value: $reps, in: 1...100) {
                Text("Reps: \(reps)").monospacedDigit().fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44)
            if enableRIR || editing?.rir != nil {
                Toggle("Record reps in reserve", isOn: $recordEffort)
                    .fixedSize(horizontal: false, vertical: true)
                if recordEffort {
                    Stepper(value: $rir, in: 0...6, step: 0.5) {
                        Text("Reps in reserve: \(rir.formatted())")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("How many more reps could you have done?")
                        .font(.footnote).foregroundStyle(CoachStyle.muted)
                }
            }
            if editing != nil {
                Button("Cancel edit") {
                    editing = nil
                    fill(from: sortedLogs.last)
                    scrollTarget = "savedSets"
                }
                    .buttonStyle(CoachActionStyle(primary: false))
            }
        }
        .coachCard()
    }

    private var savedSets: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved sets").font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(sortedLogs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set \(log.setIdx)").font(.subheadline.weight(.semibold))
                    Text("\(log.reps) reps · \(WeightUnit.formatted(log.actualWeight ?? 0, useKilograms: unitsKg))")
                        .foregroundStyle(CoachStyle.muted)
                    if exercise.day.status != .skipped {
                        Button("Edit set \(log.setIdx)") {
                            editing = log
                            fill(from: log)
                            scrollTarget = "setEntry"
                        }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
            }
        }
        .coachCard()
    }

    private var enteredWeight: Double? {
        try? FloatingPointFormatStyle<Double>.number.locale(locale).parseStrategy.parse(weightText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func fill(from log: ExerciseLog?) {
        let kg = log?.actualWeight ?? exercise.targetWeight ?? 0
        weightText = WeightUnit.display(kg, useKilograms: unitsKg)
            .formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...3)))
        reps = log?.reps ?? exercise.targetRepsMin
        if reps > 100 { reps = 100 }
        rir = log?.rir ?? (exercise.phase == "HYP" ? 2 : 1)
        recordEffort = log?.rir != nil
    }

    private func adjustWeight(by delta: Double) {
        let base = enteredWeight.map { WeightUnit.kilograms($0, useKilograms: unitsKg) } ?? exercise.targetWeight ?? 0
        weightText = WeightUnit.display(min(500, max(0, base + delta)), useKilograms: unitsKg)
            .formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...3)))
    }

    private func clearTimer() {
        exercise.day.restUntil = nil
        do { try context.save() }
        catch { context.rollback(); errorMessage = error.localizedDescription }
    }

    private func saveSet() {
        weightFocused = false
        guard let enteredWeight else { errorMessage = "Enter a valid weight."; return }
        let kg = WeightUnit.kilograms(enteredWeight, useKilograms: unitsKg)
        do {
            if let log = editing {
                nextTarget = try WorkoutLogging.editSet(log, kilograms: kg, reps: reps,
                    rir: recordEffort ? rir : nil, barbellIncrement: barbellInc, dumbbellIncrement: dbInc, context: context)
                editing = nil
                scrollTarget = "savedSets"
            } else {
                nextTarget = try WorkoutLogging.saveSet(exercise: exercise, kilograms: kg, reps: reps,
                    rir: recordEffort ? rir : nil, barbellIncrement: barbellInc, dumbbellIncrement: dbInc, context: context)
            }
            fill(from: sortedLogs.last)
        } catch { errorMessage = error.localizedDescription }
    }
}
