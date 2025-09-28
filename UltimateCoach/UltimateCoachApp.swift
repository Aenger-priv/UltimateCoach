//
//  UltimateCoachApp.swift
//  UltimateCoach
//
//  Created by Anders Enger on 28/09/2025.
//

import SwiftUI
import SwiftData

@main
struct UltimateCoachApp: App {
    // SwiftData container with app models
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Program.self,
            DayPlan.self,
            ExerciseTemplate.self,
            DayExercise.self,
            ExerciseLog.self,
            ProgressionRule.self,
            PhaseState.self,
            Conditioning.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
