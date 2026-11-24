import SwiftUI

struct RestTimer: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let deadline: Date
    var suggestion = false
    let onExtend: () -> Void
    let onEnd: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = Int(ceil(max(0, deadline.timeIntervalSince(timeline.date))))
            if remaining > 0 {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        countdown(remaining).fixedSize()
                        Spacer(minLength: 0)
                        controls.fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        countdown(remaining)
                        controls
                    }
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: 656)
                .frame(maxWidth: .infinity)
                .background(.bar)
            } else {
                Label("Rest complete", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CoachStyle.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
    }

    private func countdown(_ remaining: Int) -> some View {
        Label("\(remaining / 60):\(String(format: "%02d", remaining % 60))", systemImage: "timer")
            .monospacedDigit().font(.headline).foregroundStyle(CoachStyle.accent)
            .accessibilityLabel("Rest timer")
            .accessibilityValue("\(remaining) seconds remaining")
            .accessibilityIdentifier("restCountdown")
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(action: onExtend) {
                Text(suggestion ? "Suggested +30 sec" : "+30 sec").fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
            }
            .accessibilityLabel(suggestion ? "Suggested: add 30 seconds" : "Add 30 seconds")
            Button(action: onEnd) {
                Text("End rest").fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
            }
        }
        .font((typeSize.isAccessibilitySize ? Font.footnote : .subheadline).weight(.semibold))
    }
}
