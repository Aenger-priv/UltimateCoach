import SwiftUI
import SwiftData

@main
struct UltimateCoachApp: App {
    @UIApplicationDelegateAdaptor(RestWhistle.self) private var restWhistle
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
        let container = try ModelContainer(for: Program.self, DayPlan.self, ExerciseTemplate.self, DayExercise.self,
                                  ExerciseLog.self, ProgressionRule.self, PhaseState.self, Conditioning.self,
                                  configurations: ModelConfiguration(isStoredInMemoryOnly: testStore))
        #if DEBUG
        if testStore, ProcessInfo.processInfo.arguments.contains("--rest-offer") {
            let context = container.mainContext
            let program = try SeedData.startCycle(.strength, starts: .now, context: context)
            if let day = program.days.first(where: { $0.dayIdx == 1 && $0.weekIdx == 1 }),
               let lift = day.exercises.first(where: { $0.orderIdx == 0 }), let weight = lift.targetWeight {
                try WorkoutSession.start(day, context: context)
                _ = try WorkoutLogging.logSet(exercise: lift, kilograms: weight, reps: lift.targetRepsMin, rir: 2,
                                              barbellIncrement: 2.5, dumbbellIncrement: 2, context: context,
                                              adaptiveRest: true, restDraw: { 0 })
            }
        } else if testStore, ProcessInfo.processInfo.arguments.contains("--cycle-progress") {
            try seedCycleProgress(in: container.mainContext)
        } else if testStore, ProcessInfo.processInfo.arguments.contains("--expired-cycle") {
            let start = Calendar.current.date(byAdding: .day, value: -100, to: .now) ?? .distantPast
            try SeedData.startCycle(.hypertrophy, starts: start, context: container.mainContext)
        } else if testStore, ProcessInfo.processInfo.arguments.contains("--missed-workout") {
            let start = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
            try SeedData.startCycle(.hypertrophy, starts: start, context: container.mainContext)
        }
        #endif
        return container
    }

    #if DEBUG
    private static func seedCycleProgress(in context: ModelContext) throws {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let program = try SeedData.startCycle(.hypertrophy, starts: start, context: context)
        for day in program.days where day.dayIdx == 1 && day.weekIdx <= 2 {
            guard let date = day.date, let bench = day.exercises.first(where: { $0.orderIdx == 0 }),
                  let conditioning = day.conditioning else { continue }
            try WorkoutSession.start(day, context: context, now: date)
            for index in 1...bench.sets {
                let log = ExerciseLog(dayExercise: bench, setIdx: index, actualWeight: 50,
                                      reps: day.weekIdx == 1 ? 8 : 9, rir: 2, timestamp: date)
                context.insert(log)
                if !bench.logs.contains(where: { $0 === log }) { bench.logs.append(log) }
            }
            try WorkoutSession.recordConditioning(conditioning, minutes: 15, meters: day.weekIdx == 1 ? 3000 : 3050,
                                                  context: context, now: date)
            try WorkoutSession.finish(day, context: context, now: date)
        }
    }
    #endif
}
