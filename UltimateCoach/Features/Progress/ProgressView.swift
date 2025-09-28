import SwiftUI
import SwiftData

struct ProgressScreen: View {
    @Environment(\.modelContext) private var context
    @Query private var templates: [ExerciseTemplate]

    var body: some View {
        NavigationStack {
            List {
                ForEach(templates.sorted(by: { $0.name < $1.name })) { tpl in
                    HStack {
                        Text(tpl.name)
                        Spacer()
                        Text(latest1RMString(template: tpl))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }

    private func latest1RMString(template: ExerciseTemplate) -> String {
        // Find latest log event and estimate 1RM
        let templateID = template.persistentModelID
        let req = FetchDescriptor<DayExercise>(
            predicate: #Predicate<DayExercise> { $0.template.persistentModelID == templateID }
        )
        guard let ex = try? context.fetch(req) else { return "" }
        let logs = ex.flatMap { $0.logs }.sorted { $0.timestamp > $1.timestamp }
        guard let latest = logs.first, let w = latest.actualWeight else { return "" }
        let est = epley1RM(weight: w, reps: latest.reps)
        return String(format: "1RM: %.1f kg", est)
    }
}
