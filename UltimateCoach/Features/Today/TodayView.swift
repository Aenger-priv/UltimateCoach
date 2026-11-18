import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \DayPlan.date) private var allDays: [DayPlan]
    @Query private var programs: [Program]
    private var days: [DayPlan] { allDays.filter { !$0.program.isArchived } }
    private var activeProgram: Program? { programs.first { !$0.isArchived } }
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(currentDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CoachStyle.muted)
                    if let active = days.first(where: { $0.status == .inProgress }) {
                        workoutCard(active, eyebrow: "IN PROGRESS", action: "Resume workout")
                    } else if let program = activeProgram, program.stage(now: currentDate) == .readyForNextTrack {
                        CycleActions(program: program, now: currentDate).coachCard()
                    } else if let today = days.first(where: isToday) {
                        workoutCard(today, eyebrow: today.status == .finished ? "SESSION SAVED" : "ON THE SCHEDULE",
                                    action: today.status == .finished ? "View workout" : "Open workout")
                    } else if let next = nextWorkout {
                        Text("Rest day").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        workoutCard(next, eyebrow: "UP NEXT", action: "Preview workout")
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No upcoming workouts").font(.title2.bold())
                            Text("Open Program to review your schedule and revisit missed workouts.")
                                .foregroundStyle(CoachStyle.muted)
                        }
                        .coachCard()
                    }
                    if !laterWorkouts.isEmpty {
                        Text("Coming up").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                        ForEach(laterWorkouts) { day in
                            NavigationLink {
                                WorkoutScreen(day: day)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(day.isDeload ? "Deload · Day \(day.dayIdx)" : "Week \(day.weekIdx) · Day \(day.dayIdx)").font(.headline)
                                        if let date = day.date {
                                            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                                .font(.subheadline).foregroundStyle(CoachStyle.muted)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                                        .foregroundStyle(CoachStyle.muted).accessibilityHidden(true)
                                }
                                .coachCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .coachPage()
            }
            .coachBackground()
            .navigationTitle("Today")
            .onChange(of: scenePhase) { _, phase in if phase == .active { currentDate = Date() } }
        }
    }

    private func workoutCard(_ day: DayPlan, eyebrow: String, action: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(eyebrow, systemImage: "bolt.fill")
                .font(.caption.weight(.bold)).tracking(1)
                .foregroundStyle(CoachStyle.accent)
            Text(day.isDeload ? "Deload · Day \(day.dayIdx)" : "Week \(day.weekIdx) · Day \(day.dayIdx)")
                .font(.title.weight(.bold)).accessibilityAddTraits(.isHeader)
            if let date = day.date, !Calendar.current.isDate(date, inSameDayAs: currentDate) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .foregroundStyle(CoachStyle.muted)
            }
            Text("\(day.exercises.count) exercises · \(day.plannedSets) sets")
                .foregroundStyle(CoachStyle.muted)
            if day.status == .inProgress, day.plannedSets > 0 {
                ProgressView(value: min(Double(day.loggedSets) / Double(day.plannedSets), 1))
                    .accessibilityLabel("Workout progress")
                    .accessibilityValue("\(day.loggedSets) of \(day.plannedSets) sets saved")
            }
            NavigationLink { WorkoutScreen(day: day) } label: {
                Label(action, systemImage: "arrow.right")
            }
            .buttonStyle(CoachActionStyle())
        }
        .coachCard()
    }

    private func isToday(_ day: DayPlan) -> Bool {
        day.status != .skipped && day.date.map { Calendar.current.isDate($0, inSameDayAs: currentDate) } == true
    }

    private var upcoming: [DayPlan] {
        days.filter { $0.status == .planned && ($0.date ?? .distantPast) > currentDate }
    }

    private var nextWorkout: DayPlan? { upcoming.first }

    private var laterWorkouts: [DayPlan] {
        let hasCurrentWorkout = days.contains { $0.status == .inProgress || isToday($0) }
        return Array(upcoming.dropFirst(hasCurrentWorkout ? 0 : 1).prefix(2))
    }
}
