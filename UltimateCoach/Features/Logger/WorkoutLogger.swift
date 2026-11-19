import SwiftUI
import SwiftData

struct WorkoutLogger: View {
    @State private var exercise: DayExercise
    @Binding var lastSaved: WorkoutLogging.SavedSet?

    init(exercise: DayExercise, lastSaved: Binding<WorkoutLogging.SavedSet?>) {
        _exercise = State(initialValue: exercise)
        _lastSaved = lastSaved
    }

    var body: some View {
        let next = exercise.day.nextExercise(excluding: exercise)
        LoggerSheetView(exercise: exercise, lastSaved: $lastSaved, onNext: next.map { next in
            { exercise = next }
        })
        .id(exercise.persistentModelID)
    }
}
