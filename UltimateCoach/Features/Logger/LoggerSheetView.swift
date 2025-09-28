import SwiftUI
import SwiftData
import Observation

struct LoggerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var exercise: DayExercise

    @AppStorage("units_kg") private var unitsKg: Bool = true
    @AppStorage("barbell_inc") private var barbellInc: Double = 2.5
    @AppStorage("db_inc") private var dbInc: Double = 2.0
    @AppStorage("enable_rir") private var enableRIR: Bool = true

    @State private var weight: Double = 0
    @State private var reps: Int = 8
    @State private var rir: Double = 2
    @State private var setIdx: Int = 1
    @State private var showNextTargets: Target? = nil
    @State private var showTimer = false
    @State private var rest: Int = 90

    var body: some View {
        VStack(spacing: 12) {
            Text(exercise.template.name).font(.headline)
            HStack(spacing: 12) {
                Stepper(value: $weight, in: 0...500, step: inc) { Text("Weight: \(displayWeight(weight))") }
                Stepper(value: $reps, in: 1...30, step: 1) { Text("Reps: \(reps)") }
                if enableRIR {
                    Stepper(value: $rir, in: 0...6, step: 0.5) { Text("RIR: \(rir, specifier: "%.1f")") }
                }
            }
            .font(.body)

            HStack {
                Button("Save Set", systemImage: "checkmark.circle.fill") { saveSet() }
                    .buttonStyle(.borderedProminent)
                Button("Done", systemImage: "xmark.circle") { dismiss() }
            }

            if let t = showNextTargets {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Next targets", systemImage: "arrow.right.circle")
                        .font(.subheadline.bold())
                    Text(nextTargetSummary(t))
                        .font(.footnote)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            }

            if showTimer { RestTimer(seconds: rest) }
        }
        .padding()
        .onAppear {
            setIdx = exercise.logs.count + 1
            weight = exercise.targetWeight ?? 0
            reps = max(exercise.targetRepsMin, min(exercise.targetRepsMax, 8))
            rest = exercise.template.restSec
        }
    }

    private var inc: Double { exercise.template.equipment == "barbell" ? barbellInc : dbInc }

    private func displayWeight(_ w: Double) -> String {
        if unitsKg { return String(format: "%.1f kg", w) }
        return String(format: "%.1f lb", w * 2.20462)
    }

    private func saveSet() {
        let logsBefore = exercise.logs.count
        let set = ExerciseLog(dayExercise: exercise, setIdx: logsBefore + 1, actualWeight: weightForKg(), reps: reps, rir: enableRIR ? rir : nil)
        context.insert(set)
        try? context.save()

        // Rest timer
        showTimer = true

        // Advance or finish
        if logsBefore + 1 >= exercise.sets { // completing this set
            computeAndPersistNextTargets()
        }
    }

    private func weightForKg() -> Double {
        return unitsKg ? weight : (weight / 2.20462)
    }

    private func computeAndPersistNextTargets() {
        // Build engine inputs
        let lastLogs: [SetLog] = exercise.logs.map { SetLog(weight: $0.actualWeight, reps: $0.reps, rir: $0.rir) }
        let lastTarget = Target(weight: exercise.targetWeight, repMin: exercise.targetRepsMin, repMax: exercise.targetRepsMax, sets: exercise.sets, phase: exercise.phase)
        let rule = Rule(equipment: exercise.template.equipment, barbellInc: barbellInc, dbInc: dbInc, deloadPct: 0.10, missLimit: 3)
        let next = computeNextTargets(lastLogs: lastLogs, lastTarget: lastTarget, rule: rule, phase: exercise.phase, consecutiveMisses: 0, blockStartLoad: nil)
        withAnimation { showNextTargets = next }

        // Persist to next exposure if available (same template, next week)
        if let day = exercise.day as DayPlan? {
            let nextWeek = day.weekIdx + 1
            let programID = day.program.persistentModelID // capture identity outside #Predicate
            let req = FetchDescriptor<DayPlan>(predicate: #Predicate<DayPlan> { $0.program.persistentModelID == programID && $0.weekIdx == nextWeek })
            if let targetDay = try? context.fetch(req).first {
                if let nextEx = targetDay.exercises.first(where: { $0.template.name == exercise.template.name }) {
                    nextEx.targetWeight = next.weight
                    nextEx.targetRepsMin = next.repMin
                    nextEx.targetRepsMax = next.repMax
                    nextEx.sets = next.sets
                    try? context.save()
                }
            }
        }
    }

    private func nextTargetSummary(_ t: Target) -> String {
        let w: String
        if let tw = t.weight {
            w = unitsKg ? String(format: "%.1f kg", tw) : String(format: "%.1f lb", tw * 2.20462)
        } else { w = "bodyweight" }
        return "\(t.sets)x\(t.repMin)-\(t.repMax) @ \(w) (\(t.phase))"
    }
}
