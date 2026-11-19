import SwiftUI
import SwiftData

struct WorkoutRescheduleSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let day: DayPlan
    @State private var chosenDate: Date
    @State private var errorMessage: String?

    init(day: DayPlan) {
        self.day = day
        _chosenDate = State(initialValue: WorkoutSession.suggestedRescheduleDate(for: day))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("New workout date", selection: $chosenDate, displayedComponents: .date)
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                } footer: {
                    Text("Moves this workout only. Other workout dates and targets stay the same.")
                }
            }
            .onChange(of: chosenDate) { _, _ in errorMessage = nil }
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        do {
            try WorkoutSession.reschedule(day, to: chosenDate, context: context)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
