import SwiftUI
import SwiftData

struct WorkoutScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize
    let day: DayPlan
    @State private var selectedExercise: DayExercise?
    @State private var selectedTarget: DayExercise?
    @State private var showConditioning = false
    @State private var showReschedule = false
    @State private var chosenDate = Date()
    @State private var confirmFinish = false
    @State private var confirmSkip = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summary
                if day.status == .planned {
                    Button("Start workout", systemImage: "play.fill") { attempt { try WorkoutSession.start(day, context: context) } }
                        .buttonStyle(CoachActionStyle())
                    if !day.hasResults {
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                        layout {
                            Button("Reschedule", systemImage: "calendar") {
                                chosenDate = day.date ?? .now
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
                if day.status == .inProgress, let deadline = day.restUntil {
                    RestTimer(deadline: deadline, onClear: { attempt {
                        day.restUntil = nil
                        do { try context.save() } catch { context.rollback(); throw error }
                    } })
                    .coachCard()
                }
                Text("Exercises").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                ForEach(day.exercises.sorted { $0.orderIdx < $1.orderIdx }) { exercise in
                    ExerciseCardView(exercise: exercise, onLog: { selectedExercise = exercise },
                                     onEditTarget: { selectedTarget = exercise })
                }
                if let conditioning = day.conditioning {
                    ConditioningCardView(conditioning: conditioning) { showConditioning = true }
                }
            }
            .coachPage()
        }
        .coachBackground()
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if day.status == .inProgress {
                Button("Finish workout", systemImage: "checkmark.circle") {
                    if day.loggedSets < day.plannedSets { confirmFinish = true }
                    else { attempt { try WorkoutSession.finish(day, context: context) } }
                }
                .buttonStyle(CoachActionStyle())
                .disabled(!day.hasResults)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .frame(maxWidth: 656)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
        .sheet(item: $selectedExercise) { LoggerSheetView(exercise: $0) }
        .sheet(item: $selectedTarget) { TargetLoadSheet(exercise: $0) }
        .sheet(isPresented: $showConditioning) {
            if let conditioning = day.conditioning { ConditioningLogSheet(conditioning: conditioning) }
        }
        .sheet(isPresented: $showReschedule) {
            NavigationStack {
                Form {
                    DatePicker("New workout date", selection: $chosenDate, displayedComponents: .date)
                }
                .navigationTitle("Reschedule")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showReschedule = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do {
                                try WorkoutSession.reschedule(day, to: chosenDate, context: context)
                                showReschedule = false
                            } catch {
                                showReschedule = false
                                message = error.localizedDescription
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Finish with sets remaining?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish and save") { attempt { try WorkoutSession.finish(day, context: context) } }
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

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.status.rawValue)
                .font(.subheadline.weight(.semibold)).foregroundStyle(CoachStyle.accent)
            Text("Week \(day.weekIdx) · Day \(day.dayIdx)")
                .font(.title.bold()).accessibilityAddTraits(.isHeader)
            if let date = day.date { Text(date.formatted(date: .complete, time: .omitted)) }
            Text("\(day.loggedSets) of \(day.plannedSets) sets saved")
                .foregroundStyle(CoachStyle.muted)
        }
        .coachCard()
    }

    private func attempt(_ action: () throws -> Void) {
        do { try action() }
        catch { message = error.localizedDescription }
    }
}
