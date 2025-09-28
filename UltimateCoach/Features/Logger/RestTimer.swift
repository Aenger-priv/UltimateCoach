import SwiftUI
import Combine

struct RestTimer: View {
    @State private var remaining: Int
    @State private var running = true
    private let total: Int

    init(seconds: Int) {
        _remaining = State(initialValue: max(0, seconds))
        total = max(0, seconds)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("Rest: \(remaining)s")
                .monospacedDigit()
                .font(.title3.bold())
            ProgressView(value: Double(total - remaining), total: Double(max(1, total)))
                .tint(.blue)
            HStack {
                Button(running ? "Pause" : "Resume") { running.toggle() }
                Button("Reset") { remaining = total }
            }
            .font(.footnote)
        }
        .padding(8)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard running else { return }
            if remaining > 0 { remaining -= 1 }
        }
    }
}
