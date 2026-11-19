import SwiftUI

struct ExerciseCardView: View {
    @AppStorage("units_kg") private var unitsKg = true
    let exercise: DayExercise
    var onLog: () -> Void
    var onEditTarget: () -> Void
    var onSwap: () -> Void

    private var canLog: Bool { exercise.day.status == .inProgress && exercise.logs.count < exercise.sets }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.template.name)
                    .font(.headline).accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                if !ExerciseSubstitution.choices(for: exercise).isEmpty {
                    Spacer(minLength: 4)
                    Menu {
                        Button("Swap exercise", systemImage: "arrow.left.arrow.right", action: onSwap)
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Options for \(exercise.template.name)")
                }
            }
            Text("\(exercise.sets) sets · \(exercise.targetRepsMin)–\(exercise.targetRepsMax) reps")
                .font(.subheadline).foregroundStyle(CoachStyle.muted)
            if let weight = exercise.targetWeight {
                Text(WeightUnit.formatted(weight, useKilograms: unitsKg))
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
            } else {
                Text("Bodyweight").font(.subheadline).foregroundStyle(CoachStyle.muted)
            }
            if let note = exercise.targetNote {
                Text(note).font(.footnote).foregroundStyle(CoachStyle.muted)
            }
            if !exercise.day.program.isArchived && exercise.day.status == .planned && exercise.logs.isEmpty {
                Button("Edit target weight", systemImage: "slider.horizontal.3", action: onEditTarget)
                    .buttonStyle(CoachActionStyle(primary: false))
                    .accessibilityLabel("Edit target weight, \(exercise.template.name)")
            }
            if canLog || !exercise.logs.isEmpty {
                Button(action: onLog) {
                    Label(canLog ? "Log set" : "View sets", systemImage: canLog ? "plus" : "list.bullet")
                }
                .buttonStyle(CoachActionStyle(primary: false))
                .accessibilityLabel("\(canLog ? "Log set" : "View sets"), \(exercise.template.name)")
                .accessibilityIdentifier("exerciseAction_\(exercise.orderIdx)")
            }
        }
        .coachCard()
    }
}
