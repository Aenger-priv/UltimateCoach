import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var programs: [Program]
    @AppStorage("rest_whistle") private var restWhistle = false

    private var whistleDeadline: Date? {
        guard restWhistle, let program = programs.first(where: { !$0.isArchived }) else { return nil }
        return program.days.first(where: { $0.status == .inProgress })?.restUntil
    }

    var body: some View {
        Group {
            if programs.isEmpty {
                StartDateSetupView()
            } else {
                TabView {
                    Tab("Today", systemImage: "bolt.fill") { TodayView() }
                    Tab("Program", systemImage: "calendar") { ProgramScreen() }
                    Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") { ProgressScreen() }
                    Tab("Settings", systemImage: "gearshape") { SettingsView() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(CoachStyle.accent)
        .onChange(of: whistleDeadline, initial: true) { _, deadline in RestWhistle.schedule(for: deadline) }
    }
}
