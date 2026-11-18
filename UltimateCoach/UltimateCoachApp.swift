import SwiftUI
import SwiftData

@main
struct UltimateCoachApp: App {
    @State private var store: Result<ModelContainer, any Error> = Result { try makeStore() }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                ContentView().modelContainer(container)
            case .failure:
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Could not open workouts", systemImage: "externaldrive.badge.exclamationmark")
                            .font(.title2.bold())
                        Text("Your data remains on this device. Try opening the workout store again.")
                            .foregroundStyle(CoachStyle.muted)
                        Button("Try again", systemImage: "arrow.clockwise") {
                            store = Result { try Self.makeStore() }
                        }
                        .buttonStyle(CoachActionStyle())
                    }
                    .coachCard()
                    .coachPage()
                }
                .coachBackground()
                .preferredColorScheme(.dark)
            }
        }
    }

    private static func makeStore() throws -> ModelContainer {
        #if DEBUG
        let testStore = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        let testStore = false
        #endif
        return try ModelContainer(for: Program.self, DayPlan.self, ExerciseTemplate.self, DayExercise.self,
                                  ExerciseLog.self, ProgressionRule.self, PhaseState.self, Conditioning.self,
                                  configurations: ModelConfiguration(isStoredInMemoryOnly: testStore))
    }
}
