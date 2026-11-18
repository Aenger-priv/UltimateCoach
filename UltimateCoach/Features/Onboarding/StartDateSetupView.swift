import SwiftUI
import SwiftData

struct StartDateSetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let previous: Program?
    @State private var selectedTrack: TrainingTrack
    @State private var selectedDate: Date
    @State private var changeDate = false
    @State private var errorMessage: String?

    init(previous: Program? = nil) {
        self.previous = previous
        let recommended = (previous?.track ?? .hypertrophy).alternate
        _selectedTrack = State(initialValue: previous == nil ? .hypertrophy : recommended)
        _selectedDate = State(initialValue: max(Date(), Self.earliestStart(after: previous)))
    }

    private var minimumDate: Date {
        Self.earliestStart(after: previous)
    }

    private static func earliestStart(after previous: Program?) -> Date {
        guard let previous else { return .distantPast }
        if let archivedAt = previous.archivedAt { return Calendar.current.startOfDay(for: archivedAt) }
        return previous.nextStartDate()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "dumbbell.fill")
                        .font(.largeTitle.weight(.semibold)).foregroundStyle(CoachStyle.accent)
                        .accessibilityHidden(true)
                    Text(previous == nil ? "Choose your training track" : "Choose your next track")
                        .font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Text("12 training weeks · 4 sessions per week · 1 lighter week")
                        .font(.subheadline).foregroundStyle(CoachStyle.muted)
                    if let previous {
                        Text(previous.isArchived
                             ? "Your new cycle starts at Week 1 with fresh weight targets. Your old workouts are in Progress."
                             : "\((previous.track ?? .hypertrophy).alternate.title) is suggested after your last cycle. You can repeat either track.")
                            .foregroundStyle(CoachStyle.muted)
                    }
                    ForEach(TrainingTrack.allCases) { track in
                        trackCard(track)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Pick a different start date", isOn: $changeDate)
                            .fixedSize(horizontal: false, vertical: true)
                        if changeDate {
                            DatePicker("Start date", selection: $selectedDate, in: minimumDate..., displayedComponents: .date)
                        }
                        Text("Review the starting weights before lifting. You can edit each planned weight.")
                            .font(.subheadline).foregroundStyle(CoachStyle.muted)
                    }
                    .coachCard()
                    Button(previous == nil && !changeDate ? "Use Today" : "Start \(selectedTrack.title) cycle",
                           systemImage: "arrow.right") { createCycle() }
                        .buttonStyle(CoachActionStyle())
                        .accessibilityIdentifier("createCycle")
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
                .coachPage()
            }
            .coachBackground()
            .toolbar {
                if previous != nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
            }
        }
    }

    private func trackCard(_ track: TrainingTrack) -> some View {
        let selected = track == selectedTrack
        return Button {
            selectedTrack = track
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title).font(.headline)
                    Text(track.summary).font(.subheadline).foregroundStyle(CoachStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? CoachStyle.accent : CoachStyle.muted)
                    .accessibilityHidden(true)
            }
            .coachCard()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(track.title)
        .accessibilityHint(track.summary)
        .accessibilityIdentifier("track_\(track.rawValue)")
    }

    private func createCycle() {
        errorMessage = nil
        do {
            try SeedData.startCycle(selectedTrack, starts: changeDate ? selectedDate : max(Date(), minimumDate), context: context)
            if previous != nil { dismiss() }
        } catch { errorMessage = error.localizedDescription }
    }
}
