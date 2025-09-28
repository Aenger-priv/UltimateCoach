import SwiftUI
import SwiftData

struct StartDateSetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("did_setup_start_date") private var didSetup = false

    @State private var selectedDate: Date = Date()
    @State private var seeding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Set Program Start Date").font(.title2).bold()
                    Text("Choose today or pick a historical date to anchor your 12‑week plan.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                DatePicker("Start Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .accessibilityLabel("Program start date")

                HStack(spacing: 12) {
                    Button {
                        selectedDate = Date()
                        Task { await seed(with: selectedDate) }
                    } label: {
                        Label("Use Today", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await seed(with: selectedDate) }
                    } label: {
                        Label("Continue", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                }

                if let err = errorMessage {
                    Text(err).foregroundStyle(.red).font(.footnote)
                }

                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                if seeding { ProgressView().padding() }
            }
        }
    }

    private func seed(with date: Date) async {
        seeding = true
        defer { seeding = false }
        await SeedData.seedIfNeeded(context: context, overrideStartDate: Calendar.current.startOfDay(for: date))
        didSetup = true
        try? context.save()
        await MainActor.run { dismiss() }
    }
}

