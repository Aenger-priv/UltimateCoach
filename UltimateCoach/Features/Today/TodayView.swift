import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var days: [DayPlan] = []

    @State private var selectedExercise: DayExercise?
    @State private var showLogger = false
    @State private var isSeeding = false
    @State private var debugInfo: String = ""

    var body: some View {
        NavigationStack {
            List {
                if let day = todayDay {
                    Section(header: Text("Week \(day.weekIdx) · Day \(day.dayIdx)")) {
                        ForEach(exercises(for: day), id: \.persistentModelID) { ex in
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
                    if !debugInfo.isEmpty {
                        Text(debugInfo).font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loading program…")
                            .foregroundStyle(.secondary)
                        if !debugInfo.isEmpty {
                            Text(debugInfo).font(.footnote).foregroundStyle(.secondary)
                        }
                        Button("Force Seed Now") {
                            Task {
                                isSeeding = true
                                await SeedData.seedIfNeeded(context: context)
                                try? context.save()
                                isSeeding = false
                                debugInfo = SeedData.lastStatus
                                await loadDays()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                }
            }
            .navigationTitle("Today")
            .task {
                await loadDays()
                if days.isEmpty {
                    isSeeding = true
                    await SeedData.seedIfNeeded(context: context)
                    try? context.save()
                    isSeeding = false
                    debugInfo = SeedData.lastStatus
                    await loadDays()
                    if days.isEmpty {
                        // Emergency minimal seed to avoid empty UI
                        await emergencySeed()
                        await loadDays()
                        debugInfo = SeedData.lastStatus + " | after emergency: Programs: \((try? context.fetchCount(FetchDescriptor<Program>())) ?? -1), Days: \(days.count)"
                    }
                } else {
                    // If we have days but no exercises on current week/day, try to backfill from seed
                    if (todayDay?.exercises.isEmpty ?? true) {
                        await SeedData.fillMissingExercisesIfNeeded(context: context)
                        await loadDays()
                    }
                }
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
    @MainActor private func loadDays() async {
        do {
            let desc = FetchDescriptor<DayPlan>(sortBy: [SortDescriptor(\.weekIdx), SortDescriptor(\.dayIdx)])
            days = try context.fetch(desc)
            let pCount = try context.fetchCount(FetchDescriptor<Program>())
            let dCount = days.count
            debugInfo = "Programs: \(pCount), Days: \(dCount)"
        } catch {
            print("Load days error: \(error)")
            debugInfo = "Load error: \(error.localizedDescription)"
        }
    }

    @MainActor private func exercises(for day: DayPlan) -> [DayExercise] {
        return day.exercises.sorted { $0.orderIdx < $1.orderIdx }
    }

    @MainActor private func emergencySeed() async {
        let start = Calendar.current.startOfDay(for: Date())
        let program = Program(name: "Default Program", startDate: start, totalWeeks: 12)
        context.insert(program)
        let day = DayPlan(program: program, weekIdx: 1, dayIdx: 1)
        day.date = SeedData.computeDate(start: start, weekIdx: 1, dayIdx: 1)
        context.insert(day)
        program.days.append(day)
        let bench = ExerciseTemplate(name: "Bench Press", muscleGroup: "chest", equipment: "barbell", defaultSets: 3, repMin: 8, repMax: 12, restSec: 120)
        context.insert(bench)
        let ex = DayExercise(day: day, template: bench, targetWeight: 60, targetRepsMin: 8, targetRepsMax: 12, sets: 3, orderIdx: 0, phase: "HYP")
        context.insert(ex)
        day.exercises.append(ex)
        do {
            try context.save()
            debugInfo = (debugInfo + " | emergency seed OK")
        } catch {
            debugInfo = (debugInfo + " | emergency save error: \(error.localizedDescription)")
        }
    }
}
