import SwiftUI
import SwiftData

struct CycleActions: View {
    @Environment(\.modelContext) private var context
    let program: Program
    let now: Date
    @State private var choosingTrack = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch program.stage(now: now) {
            case .training:
                EmptyView()
            case .deload:
                Text("Deload week").font(.headline)
                Text("Use fewer sets and lighter weights. Aim to finish with at least four reps in reserve.")
                    .foregroundStyle(CoachStyle.muted)
            case .readyForNextTrack:
                Text("Plan your next cycle").font(.headline)
                Text("Suggested: \((program.track ?? .hypertrophy).alternate.title). Your past workouts stay in Progress.")
                    .foregroundStyle(CoachStyle.muted)
                Button("Choose next track", systemImage: "arrow.right") { choosingTrack = true }
                    .buttonStyle(CoachActionStyle())
                if program.deloadWeek == nil {
                    Button("Add a deload week", systemImage: "calendar.badge.plus") {
                        do { try SeedData.addRecoveryToLegacy(program, context: context, now: now) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    .buttonStyle(CoachActionStyle(primary: false))
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .sheet(isPresented: $choosingTrack) { StartDateSetupView(previous: program) }
    }
}
