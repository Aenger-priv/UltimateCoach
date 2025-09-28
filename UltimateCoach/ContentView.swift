//
//  ContentView.swift
//  UltimateCoach
//
//  Created by Anders Enger on 28/09/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("did_setup_start_date") private var didSetup = false
    @State private var showStartDateSetup = false

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "calendar") }
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear {
            evaluateSetup()
            Task { await ensureSeededIfNeeded() }
        }
        .fullScreenCover(isPresented: $showStartDateSetup, onDismiss: {
            Task { await ensureSeededIfNeeded() }
        }) {
            StartDateSetupView()
        }
    }

    private func evaluateSetup() {
        let count = (try? context.fetchCount(FetchDescriptor<Program>())) ?? 0
        let hasProgram = count > 0
        showStartDateSetup = !hasProgram
    }

    @MainActor
    private func ensureSeededIfNeeded() async {
        let dayCount = (try? context.fetchCount(FetchDescriptor<DayPlan>())) ?? 0
        if dayCount == 0 {
            let program = try? context.fetch(FetchDescriptor<Program>()).first
            await SeedData.seedIfNeeded(context: context, overrideStartDate: program?.startDate)
        }
    }
}

#Preview {
    ContentView()
}
