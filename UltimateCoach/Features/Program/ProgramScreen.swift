import SwiftUI
import SwiftData

struct ProgramScreen: View {
    @Query private var programs: [Program]
    @State private var selectedWeek: Int?

    var body: some View {
        NavigationStack {
            List {
                if let program = programs.first {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(program.name).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                            Text("\(program.totalWeeks) weeks · \(program.days.count) workouts")
                                .foregroundStyle(CoachStyle.muted)
                        }
                        .padding(.vertical, 7)
                        Picker("Training week", selection: Binding(
                            get: { selectedWeek ?? currentWeek(program) }, set: { selectedWeek = $0 }
                        )) {
                            ForEach(1...max(1, program.totalWeeks), id: \.self) { week in
                                Text("Week \(week)").tag(week)
                            }
                        }
                    }
                    Section("Workouts") {
                        ForEach(program.days.filter { $0.weekIdx == (selectedWeek ?? currentWeek(program)) }
                            .sorted { $0.dayIdx < $1.dayIdx }) { day in
                            NavigationLink { WorkoutScreen(day: day) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Day \(day.dayIdx)").font(.headline)
                                    if let date = day.date { Text(date.formatted(date: .complete, time: .omitted)) }
                                    Text(day.status.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(day.status == .inProgress ? CoachStyle.accent : CoachStyle.muted)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .coachBackground()
            .navigationTitle("Program")
        }
    }

    private func currentWeek(_ program: Program) -> Int {
        if let active = program.days.first(where: { $0.status == .inProgress }) { return active.weekIdx }
        let today = Calendar.current.startOfDay(for: .now)
        return program.days.filter { $0.status == .planned && ($0.date ?? .distantPast) >= today }
            .min { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }?.weekIdx ?? program.totalWeeks
    }
}
