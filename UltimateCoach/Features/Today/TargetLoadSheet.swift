import SwiftUI
import SwiftData

struct TargetLoadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @AppStorage("units_kg") private var unitsKg = true
    let exercise: DayExercise
    @State private var input = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(exercise.template.name).font(.title2.bold())
                        Text("Target weight (\(unitsKg ? "kg" : "lb"))").font(.headline)
                        TextField("Weight", text: $input)
                            .keyboardType(.decimalPad)
                            .frame(minHeight: 44)
                            .accessibilityLabel(unitsKg ? "Target weight in kilograms" : "Target weight in pounds")
                        Text(exercise.template.equipment == "bodyweight"
                             ? "Enter added weight only. Enter 0 for bodyweight."
                             : "This weight applies to this workout.")
                            .font(.subheadline)
                            .foregroundStyle(CoachStyle.muted)
                    }
                    .coachCard()
                    Button("Save target weight", systemImage: "checkmark") { save() }
                        .buttonStyle(CoachActionStyle())
                }
                .coachPage()
            }
            .coachBackground()
            .navigationTitle("Edit target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Could not save target", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onAppear {
                input = WeightUnit.display(exercise.targetWeight ?? 0, useKilograms: unitsKg)
                    .formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...3)))
            }
        }
    }

    private func save() {
        do {
            let value = try FloatingPointFormatStyle<Double>.number.locale(locale).parseStrategy.parse(input)
            try WorkoutSession.setPlannedLoad(exercise, kilograms: WeightUnit.kilograms(value, useKilograms: unitsKg), context: context)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
