import SwiftUI
import SwiftData

struct ExerciseSwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @AppStorage("units_kg") private var unitsKg = true
    let exercise: DayExercise
    let onSwap: () -> Void
    @State private var selected: ExerciseSubstitution.Choice?
    @State private var weightText = ""
    @State private var includeUpcoming = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(exercise.template.name) {
                    ForEach(ExerciseSubstitution.choices(for: exercise)) { choice in
                        Button {
                            selected = choice
                            weightText = ""
                            errorMessage = nil
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(choice.name).font(.headline)
                                    Text(choice.equipment.capitalized).font(.subheadline).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if selected == choice {
                                    Image(systemName: "checkmark").foregroundStyle(CoachStyle.accent)
                                }
                            }
                            .foregroundStyle(.primary)
                            .frame(minHeight: 44)
                        }
                        .accessibilityAddTraits(selected == choice ? .isSelected : [])
                    }
                }
                if let selected {
                    Section {
                        if selected.equipment != "bodyweight" {
                            TextField(unitsKg ? "Starting weight (kg)" : "Starting weight (lb)", text: $weightText)
                                .keyboardType(.decimalPad)
                        }
                        Toggle("Also swap upcoming workouts in this slot", isOn: $includeUpcoming)
                    } footer: {
                        Text("The substitute uses the same sets and reps and has its own log history.")
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Swap exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Swap", action: swap)
                        .disabled(selected == nil || (selected?.equipment != "bodyweight" && weightText.isEmpty))
                }
            }
        }
    }

    private func swap() {
        guard let selected else { return }
        let input = try? FloatingPointFormatStyle<Double>.number.locale(locale).parseStrategy.parse(weightText)
        let kilograms = input.map { WeightUnit.kilograms($0, useKilograms: unitsKg) }
        do {
            try ExerciseSubstitution.swap(exercise, to: selected, weight: kilograms, includeUpcoming: includeUpcoming,
                                          context: context)
            onSwap()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
