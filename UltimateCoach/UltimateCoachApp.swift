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
        do {
            return try ModelContainer(for:
                Program.self,
                DayPlan.self,
                ExerciseTemplate.self,
                DayExercise.self,
                ExerciseLog.self,
                ProgressionRule.self,
                PhaseState.self,
                Conditioning.self
            )
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
