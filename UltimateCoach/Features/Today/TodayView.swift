import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var days: [DayPlan] = []

    @State private var selectedExercise: DayExercise?
    @State private var showLogger = false
    @State private var isSeeding = false
    @State private var didAttemptSeed = false

    var body: some View {
        NavigationStack {
            List {
                if let day = todayDay {
                    Section(header: Text("Week \(day.weekIdx) · Day \(day.dayIdx)")) {
                        ForEach(day.exercises.sorted(by: { $0.orderIdx < $1.orderIdx })) { ex in
                            ExerciseCardView(exercise: ex) {
                                selectedExercise = ex
                                showLogger = true
                            }
                        }
                        if let cond = day.conditioning {
                            ConditioningCardView(conditioning: cond)
                        }
                    }
                } else {
                    if isSeeding {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Seeding…")
                                .foregroundStyle(.secondary)
                        }
                } else {
                    Text("Loading program…")
                        .foregroundStyle(.secondary)
                }
                }
            }
            .navigationTitle("Today")
            .task {
                await ensureSeededIfNeeded()
                await loadDays()
            }
            .sheet(isPresented: $showLogger) {
                if let ex = selectedExercise {
                    LoggerSheetView(exercise: ex)
                        .presentationDetents([.height(320), .medium])
                }
            }
        }
    }

    private var todayDay: DayPlan? {
        // 1) Exact date match
        let today = Calendar.current.startOfDay(for: Date())
        if let match = days.first(where: { $0.date == today }) { return match }
        // 2) Next upcoming by date
        if let upcoming = days.filter({ ($0.date ?? .distantFuture) >= today })
            .sorted(by: { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) })
            .first { return upcoming }
        // 3) Earliest day (Week, Day order)
        if let earliest = days.sorted(by: { ($0.weekIdx, $0.dayIdx) < ($1.weekIdx, $1.dayIdx) }).first { return earliest }
        // 4) Most recent past by date
        return days.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }).first
    }
}

extension TodayView {
    @MainActor private func ensureSeededIfNeeded() async {
        guard !didAttemptSeed else { return }
        didAttemptSeed = true
        let dayCount = (try? context.fetchCount(FetchDescriptor<DayPlan>())) ?? 0
        if dayCount == 0 {
            isSeeding = true
            await SeedData.seedIfNeeded(context: context)
            try? context.save()
            isSeeding = false
        }
    }

    @MainActor private func loadDays() async {
        do {
            let desc = FetchDescriptor<DayPlan>(sortBy: [SortDescriptor(\.weekIdx), SortDescriptor(\.dayIdx)])
            days = try context.fetch(desc)
        } catch {
            print("Load days error: \(error)")
        }
    }
}
