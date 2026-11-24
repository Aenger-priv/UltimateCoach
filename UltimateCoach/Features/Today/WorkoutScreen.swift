import SwiftUI
import SwiftData

struct WorkoutScreen: View {
    @AppStorage("adaptive_rest") private var adaptiveRest = false
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("units_kg") private var unitsKg = true
    let day: DayPlan
    @State private var selectedExercise: DayExercise?
    @State private var selectedTarget: DayExercise?
    @State private var swapExercise: DayExercise?
    @State private var showConditioning = false
    @State private var showReschedule = false
    @State private var confirmFinish = false
    @State private var confirmSkip = false
    @State private var message: String?
    @State private var lastSaved: WorkoutLogging.SavedSet?

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView { workoutContent }
                .onChange(of: day.status) { _, status in
                    if status == .finished { scroll.scrollTo("workoutSummary", anchor: .top) }
                }
        }
        .coachBackground()
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            if day.status == .inProgress, selectedExercise == nil, let deadline = day.restUntil {
                RestTimer(deadline: deadline, suggestion: adaptiveRest && day.hasRestSuggestion,
                          onExtend: { attempt { try WorkoutSession.extendRest(day, context: context, adaptiveRest: adaptiveRest) } },
                          onEnd: { attempt { try WorkoutSession.endRest(day, context: context) } })
            }
        }
        .safeAreaInset(edge: .bottom) { workoutActions }
        .sheet(item: $selectedExercise) { WorkoutLogger(exercise: $0, lastSaved: $lastSaved) }
        .sheet(item: $selectedTarget) { TargetLoadSheet(exercise: $0) }
        .sheet(item: $swapExercise) { ExerciseSwapSheet(exercise: $0, onSwap: { lastSaved = nil }) }
        .sheet(isPresented: $showConditioning) {
            if let conditioning = day.conditioning { ConditioningLogSheet(conditioning: conditioning) }
        }
        .sheet(isPresented: $showReschedule) { WorkoutRescheduleSheet(day: day) }
        .confirmationDialog("Finish with sets remaining?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish and save", action: finishWorkout)
        } message: {
            Text("Your saved sets will appear in Progress.")
        }
        .confirmationDialog("Skip this workout?", isPresented: $confirmSkip, titleVisibility: .visible) {
            Button("Skip workout") { attempt { try WorkoutSession.skip(day, context: context) } }
        }
        .alert("Workout action failed", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }

    private var workoutContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            summary.id("workoutSummary")
            if day.status == .finished { completionSummary }
            if day.status == .planned && !day.program.isArchived {
                Button("Start workout", systemImage: "play.fill") { attempt { try WorkoutSession.start(day, context: context) } }
                    .buttonStyle(CoachActionStyle())
                if !day.hasResults {
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                    layout {
                        Button("Reschedule", systemImage: "calendar") {
                            showReschedule = true
                        }
                        Button("Skip workout", systemImage: "forward.end") { confirmSkip = true }
                    }
                    .buttonStyle(CoachActionStyle(primary: false))
                }
            }
            if day.status == .inProgress, !day.hasResults {
                Button("Cancel empty workout") { attempt { try WorkoutSession.cancelEmpty(day, context: context) } }
                    .buttonStyle(CoachActionStyle(primary: false))
            }
            Text("Exercises").font(.title3.bold()).accessibilityAddTraits(.isHeader)
            ForEach(day.exercises.sorted { $0.orderIdx < $1.orderIdx }) { exercise in
                ExerciseCardView(exercise: exercise, onLog: { selectedExercise = exercise },
                                 onEditTarget: { selectedTarget = exercise }, onSwap: { swapExercise = exercise })
            }
            if let conditioning = day.conditioning {
                ConditioningCardView(conditioning: conditioning) { showConditioning = true }
            }
        }
        .coachPage()
    }

    @ViewBuilder
    private var workoutActions: some View {
        if day.status == .inProgress {
            let next = day.nextExercise()
            VStack(alignment: .leading, spacing: 6) {
                if let next {
                    Text("\(next.template.name) · Set \(next.logs.count + 1) of \(next.sets)")
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    if let next {
                        Button("Log next set", systemImage: "plus") { selectedExercise = next }
                            .buttonStyle(CoachActionStyle())
                    }
                    if day.hasResults {
                        Button("Finish workout") {
                            if day.loggedSets < day.plannedSets { confirmFinish = true }
                            else { finishWorkout() }
                        }
                        .buttonStyle(CoachActionStyle(primary: next == nil))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(maxWidth: 656)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    @ViewBuilder
    private var completionSummary: some View {
        let upcoming = WorkoutLogging.changedTargets(after: day)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming target changes").font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(upcoming) { exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        let weight = exercise.targetWeight.map { WeightUnit.formatted($0, useKilograms: unitsKg) }
                        Text(exercise.template.name + (weight.map { " · " + $0 } ?? ""))
                            .font(.subheadline.weight(.semibold))
                        if let note = exercise.targetNote {
                            Text(note).font(.subheadline).foregroundStyle(CoachStyle.muted)
                        }
                    }
                }
            }
            .coachCard()
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.program.isArchived && day.status == .planned ? "Archived" : day.status.rawValue)
                .font(.subheadline.weight(.semibold)).foregroundStyle(CoachStyle.accent)
            Text(day.isDeload ? "Deload · \(day.workoutTitle)" : "Week \(day.weekIdx) · \(day.workoutTitle)")
                .font(.title.bold()).accessibilityAddTraits(.isHeader)
            if let date = day.date { Text(date.formatted(date: .complete, time: .omitted)) }
            if day.isDeload {
                Text("Leave at least four reps in reserve. Use a lighter load or stop earlier if needed.")
                    .foregroundStyle(CoachStyle.muted)
            }
            Text("\(day.loggedSets) of \(day.plannedSets) sets saved")
                .foregroundStyle(CoachStyle.muted)
            if let minutes = day.conditioning?.loggedMinutes {
                Text("\(minutes) min conditioning saved").foregroundStyle(CoachStyle.muted)
            }
        }
        .coachCard()
    }

    private func finishWorkout() {
        attempt {
            try WorkoutSession.finish(day, context: context)
            lastSaved = nil
        }
    }

    private func attempt(_ action: () throws -> Void) {
        do { try action() }
        catch { message = error.localizedDescription }
    }
}
