import SwiftUI
import SwiftData

struct StartDateSetupView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedDate = Date()
    @State private var changeDate = false
    @State private var seeding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "dumbbell.fill")
                        .font(.largeTitle.weight(.semibold)).foregroundStyle(CoachStyle.accent)
                        .accessibilityHidden(true)
                    Text("UltimateCoach")
                        .font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Text("Follow a strength plan, log your sets, and see what to aim for next.")
                        .font(.title3).foregroundStyle(CoachStyle.muted)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Your first program").font(.headline)
                        Text("12 weeks · 4 workouts per week").foregroundStyle(CoachStyle.muted)
                        Text("Example weights are prefilled. Enter the weight you actually use when logging each set.")
                            .font(.subheadline).foregroundStyle(CoachStyle.muted)
                        Toggle("Pick a different start date", isOn: $changeDate)
                            .fixedSize(horizontal: false, vertical: true)
                        if changeDate {
                            DatePicker("Start date", selection: $selectedDate, displayedComponents: .date)
                        }
                    }
                    .coachCard()
                    Button(changeDate ? "Create my plan" : "Use Today", systemImage: "arrow.right") {
                        Task { await seed(with: changeDate ? selectedDate : .now) }
                    }
                    .buttonStyle(CoachActionStyle())
                    if seeding { ProgressView("Creating plan…") }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
                .coachPage()
            }
            .coachBackground()
            .disabled(seeding)
        }
    }

    private func seed(with date: Date) async {
        guard !seeding else { return }
        seeding = true
        errorMessage = nil
        defer { seeding = false }
        do { try await SeedData.seedIfNeeded(context: context, overrideStartDate: date) }
        catch { errorMessage = "Could not create your plan. " + error.localizedDescription }
    }
}
