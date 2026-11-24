import SwiftUI

struct ConditioningCardView: View {
    let conditioning: Conditioning
    let onLog: () -> Void
    @State private var showRowErg = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Conditioning", systemImage: conditioning.type == "row" ? "figure.rower" : "figure.run")
                .font(.headline).accessibilityAddTraits(.isHeader)
            Text(conditioning.protocolText).foregroundStyle(CoachStyle.muted)
            if let pace = conditioning.targetPace { Text("Target pace: \(pace)").foregroundStyle(CoachStyle.muted) }
            if let minutes = conditioning.loggedMinutes {
                Text("Logged: \(minutes) min" + (conditioning.loggedMeters.map { " · \($0.formatted()) m" } ?? ""))
            }
            if conditioning.type.lowercased() == "row", !conditioning.day.program.isArchived,
               conditioning.day.status == .planned || conditioning.day.status == .inProgress {
                Button("Set up RowErg", systemImage: "figure.rower") { showRowErg = true }
                    .buttonStyle(CoachActionStyle(primary: false))
            }
            if conditioning.day.status == .inProgress {
                Button(conditioning.loggedMinutes == nil ? "Log conditioning" : "Edit conditioning",
                       systemImage: "pencil", action: onLog)
                    .buttonStyle(CoachActionStyle(primary: false))
            }
        }
        .coachCard()
        .sheet(isPresented: $showRowErg) { RowErgSetupSheet(conditioning: conditioning) }
    }
}
