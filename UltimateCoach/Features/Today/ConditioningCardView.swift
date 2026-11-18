import SwiftUI

struct ConditioningCardView: View {
    let conditioning: Conditioning
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Conditioning", systemImage: conditioning.type == "row" ? "figure.rower" : "figure.run")
                .font(.headline).accessibilityAddTraits(.isHeader)
            Text(conditioning.protocolText).foregroundStyle(CoachStyle.muted)
            if let pace = conditioning.targetPace { Text("Target pace: \(pace)").foregroundStyle(CoachStyle.muted) }
            if let minutes = conditioning.loggedMinutes {
                Text("Logged: \(minutes) min" + (conditioning.loggedMeters.map { " · \($0.formatted()) m" } ?? ""))
            }
            if conditioning.day.status == .inProgress {
                Button(conditioning.loggedMinutes == nil ? "Log conditioning" : "Edit conditioning",
                       systemImage: "pencil", action: onLog)
                    .buttonStyle(CoachActionStyle(primary: false))
            }
        }
        .coachCard()
    }
}
