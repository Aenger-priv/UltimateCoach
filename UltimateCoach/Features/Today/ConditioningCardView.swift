import SwiftUI
import Observation

struct ConditioningCardView: View {
    @Bindable var conditioning: Conditioning
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Conditioning", systemImage: conditioning.type == "row" ? "figure.rower" : "figure.run")
                    .font(.headline)
                Spacer()
            }
            Text(conditioning.protocolText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let pace = conditioning.targetPace {
                Text("Target: \(pace)")
                    .font(.footnote)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Conditioning: \(conditioning.protocolText)")
    }
}
