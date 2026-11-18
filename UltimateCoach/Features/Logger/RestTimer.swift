import SwiftUI

struct RestTimer: View {
    let deadline: Date
    let onClear: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = Int(ceil(max(0, deadline.timeIntervalSince(timeline.date))))
            VStack(alignment: .leading, spacing: 5) {
                Label("Rest timer", systemImage: "timer").font(.subheadline.weight(.semibold))
                Text(remaining == 0 ? "Rest complete" : "\(remaining / 60):\(String(format: "%02d", remaining % 60))")
                    .monospacedDigit().font(.title2.bold()).foregroundStyle(CoachStyle.accent)
                    .accessibilityLabel(remaining == 0 ? "Rest complete" : "\(remaining) seconds remaining")
                Button(remaining == 0 ? "Clear timer" : "End rest", action: onClear)
                    .frame(minHeight: 44)
            }
        }
    }
}
