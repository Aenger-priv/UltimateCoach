import SwiftUI
import SwiftData

struct ScheduleShiftSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let program: Program
    @State private var originalNextDate: Date?
    @State private var nextDate: Date
    @State private var saveError: String?

    init(program: Program) {
        self.program = program
        let first = WorkoutSession.nextUpcomingDate(in: program)
        _originalNextDate = State(initialValue: first)
        _nextDate = State(initialValue: first ?? .now)
    }

    private var shiftedStart: Date {
        guard let originalNextDate else { return program.startDate }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: originalNextDate),
                                           to: calendar.startOfDay(for: nextDate)).day ?? 0
        return calendar.date(byAdding: .day, value: days, to: program.startDate) ?? program.startDate
    }

    var body: some View {
        let preview = Result { try WorkoutSession.upcomingShift(program, to: shiftedStart) }
        NavigationStack {
            Form {
                if originalNextDate != nil {
                    Section {
                        DatePicker("Next workout date", selection: $nextDate,
                                   in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                    } footer: {
                        Text("Shifts upcoming workouts by the same number of days. Past and active workouts keep their dates.")
                    }
                }
                switch preview {
                case .failure(let error):
                    Text(error.localizedDescription).foregroundStyle(.red)
                case .success(let changes) where !changes.isEmpty:
                    Section("Preview · \(changes.count) workouts") {
                        ForEach(changes) { change in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Week \(change.day.weekIdx) · \(change.day.workoutTitle)").font(.headline)
                                Text("From \(change.oldDate.formatted(date: .abbreviated, time: .omitted))")
                                    .foregroundStyle(.secondary)
                                Text("To \(change.newDate.formatted(date: .abbreviated, time: .omitted))")
                            }
                        }
                    }
                case .success:
                    Text("No upcoming workouts would move.").foregroundStyle(.secondary)
                }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .navigationTitle("Move upcoming workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move", action: move).disabled((try? preview.get())?.isEmpty != false)
                }
            }
        }
    }

    private func move() {
        let currentNextDate = WorkoutSession.nextUpcomingDate(in: program)
        guard currentNextDate == originalNextDate else {
            originalNextDate = currentNextDate
            if let currentNextDate { nextDate = currentNextDate }
            saveError = "The next workout changed. Check the updated date before moving the schedule."
            return
        }
        do {
            try WorkoutSession.shiftUpcoming(program, to: shiftedStart, context: context)
            dismiss()
        } catch { saveError = error.localizedDescription }
    }
}
