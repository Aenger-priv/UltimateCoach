import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var programs: [Program]

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
    }
}
