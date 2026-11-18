import SwiftUI
import SwiftData

struct ProgramScreen: View {
    @Environment(\.modelContext) private var context
    @Query private var programs: [Program]
    @State private var selectedWeek: Int?
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    @State private var confirmingEarlyEnd = false
    @State private var restartFrom: Program?
    @State private var endError: String?
    private var activeProgram: Program? { programs.first { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            List {
                if let program = activeProgram {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text((program.track ?? .hypertrophy).title)
                                .font(.title2.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text(program.deloadWeek == nil
                                 ? "\(program.trainingWeeks) training weeks"
                                 : "\(program.trainingWeeks) training weeks + deload")
                                .foregroundStyle(CoachStyle.muted)
                        }
                        .padding(.vertical, 7)
                        Picker("Training week", selection: Binding(
                            get: { selectedWeek ?? currentWeek(program) }, set: { selectedWeek = $0 }
                        )) {
                            ForEach(1...max(1, program.totalWeeks), id: \.self) { week in
                                Text(week == program.deloadWeek ? "Week \(week) · Deload" : "Week \(week)").tag(week)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .accessibilityIdentifier("trainingWeekPicker")
                    }
                    if program.stage(now: now) != .training {
                        Section {
                            CycleActions(program: program, now: now)
                                .padding(.vertical, 6)
                        }
                    }
                    Section("Workouts") {
                        ForEach(program.days.filter { $0.weekIdx == (selectedWeek ?? currentWeek(program)) }
                            .sorted { ($0.date ?? .distantFuture, $0.dayIdx) < ($1.date ?? .distantFuture, $1.dayIdx) }) { day in
                            NavigationLink { WorkoutScreen(day: day) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workoutTitle(for: day))
                                        .font(.headline)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let date = day.date { Text(date.formatted(date: .complete, time: .omitted)) }
                                    Text(day.status.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(day.status == .inProgress ? CoachStyle.accent : CoachStyle.muted)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    if program.stage(now: now) != .readyForNextTrack {
                        Section {
                            Button("End program early", systemImage: "flag", role: .destructive) {
                                confirmingEarlyEnd = true
                            }
                        }
                    }
                } else if let archived = Program.latestArchived(in: programs) {
                    Section {
                        Text("Your saved workouts are in Progress.")
                            .foregroundStyle(CoachStyle.muted)
                        Button("Choose next track", systemImage: "arrow.right") { restartFrom = archived }
                            .buttonStyle(CoachActionStyle())
                    } header: {
                        Text("No active program")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .coachBackground()
            .navigationTitle("Program")
            .alert("End this program early?", isPresented: $confirmingEarlyEnd, presenting: activeProgram) { program in
                Button("End and choose a track", role: .destructive) { endProgram(program) }
                Button("Keep program", role: .cancel) {}
            } message: { _ in
                Text("The remaining workouts leave your schedule. Any open workout is closed and your saved sets and conditioning stay in Progress.")
            }
            .sheet(item: $restartFrom) { StartDateSetupView(previous: $0) }
            .alert("Could not end program", isPresented: Binding(get: { endError != nil }, set: { if !$0 { endError = nil } })) {
                Button("OK") { endError = nil }
            } message: { Text(endError ?? "") }
            .onChange(of: activeProgram?.persistentModelID) { selectedWeek = nil }
            .onAppear { now = Date() }
            .onChange(of: scenePhase) { if scenePhase == .active { now = Date() } }
        }
    }

    private func endProgram(_ program: Program) {
        do {
            try SeedData.endCycleEarly(program, context: context)
            restartFrom = program
        } catch {
            endError = error.localizedDescription
        }
    }

    private func workoutTitle(for day: DayPlan) -> String {
        // The original plan and its deload retain their original weekly slots.
        let focus: String
        switch (day.program.track, day.dayIdx) {
        case (nil, 1): focus = "Upper Push"
        case (nil, 3): focus = "Upper Pull"
        case (_, 2), (_?, 6): focus = "Lower Body"
        case (nil, 5), (_?, 1), (_?, 4): focus = "Mixed Upper"
        default: return "Day \(day.dayIdx)"
        }
        return "Day \(day.dayIdx) · \(focus)"
    }

    private func currentWeek(_ program: Program) -> Int {
        if let active = program.days.first(where: { $0.status == .inProgress }) { return active.weekIdx }
        let today = Calendar.current.startOfDay(for: now)
        return program.days.filter { $0.status == .planned && ($0.date ?? .distantPast) >= today }
            .min { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }?.weekIdx ?? program.totalWeeks
    }
}
