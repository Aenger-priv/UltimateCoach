import SwiftUI
import SwiftData
import Observation

struct ExerciseCardView: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: DayExercise
    var onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.template.name)
                    .font(.headline)
                Spacer()
                phaseBadge
            }

            Text(summaryLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text("Sets remaining: \(setsRemaining)")
                    .font(.footnote)
                Spacer()
                Button(action: onLog) {
                    Label("Log Set", systemImage: "pencil")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.template.name), \(summaryLine), \(setsRemaining) sets remaining")
    }

    private var setsRemaining: Int { max(0, exercise.sets - exercise.logs.count) }

    private var phaseBadge: some View {
        Text(exercise.phase)
            .font(.caption.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(exercise.phase == "HYP" ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var summaryLine: String {
        let w = exercise.targetWeight
        let reps = "\(exercise.sets)x\(exercise.targetRepsMin)-\(exercise.targetRepsMax)"
        if let w {
            return String(format: "%@ @ %.1f kg", reps, w)
        }
        return reps
    }
}
