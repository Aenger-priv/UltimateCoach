import SwiftUI
import SwiftData

struct ConditioningLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    let conditioning: Conditioning
    @State private var duration = ""
    @State private var distance = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(conditioning.protocolText).font(.title3.bold())
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration in minutes").font(.subheadline.weight(.semibold))
                        TextField("Minutes", text: $duration).keyboardType(.numberPad)
                            .accessibilityLabel("Duration in minutes").frame(minHeight: 44)
                        Divider()
                        Text("Distance in meters (optional)").font(.subheadline.weight(.semibold))
                        TextField("Meters", text: $distance).keyboardType(.numberPad)
                            .accessibilityLabel("Distance in meters").frame(minHeight: 44)
                    }
                    .coachCard()
                    Button("Save conditioning", systemImage: "checkmark") { save() }
                        .buttonStyle(CoachActionStyle())
                }
                .coachPage()
            }
            .coachBackground()
            .navigationTitle("Conditioning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Could not save", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
            .onAppear {
                if let saved = conditioning.loggedMinutes { duration = String(saved) }
                if let saved = conditioning.loggedMeters { distance = String(saved) }
            }
        }
    }

    private func save() {
        let parser = IntegerFormatStyle<Int>.number.locale(locale).parseStrategy
        let minutes = try? parser.parse(duration)
        let meters = try? parser.parse(distance)
        guard let minutes, distance.isEmpty || meters != nil else {
            message = "Enter a whole number for minutes and distance."
            return
        }
        do {
            try WorkoutSession.recordConditioning(conditioning, minutes: minutes, meters: meters, context: context)
            dismiss()
        } catch { message = error.localizedDescription }
    }
}
