import Foundation
import SwiftData

@Model
final class Program {
    var name: String
    var startDate: Date
    var totalWeeks: Int
    @Relationship(deleteRule: .cascade) var days: [DayPlan]

    init(name: String, startDate: Date, totalWeeks: Int) {
        self.name = name
        self.startDate = startDate
        self.totalWeeks = totalWeeks
        self.days = []
    }
}

@Model
final class DayPlan {
    var program: Program
    var weekIdx: Int
    var dayIdx: Int
    var date: Date?
    @Relationship(deleteRule: .cascade) var exercises: [DayExercise]
    var conditioning: Conditioning?

    init(program: Program, weekIdx: Int, dayIdx: Int) {
        self.program = program
        self.weekIdx = weekIdx
        self.dayIdx = dayIdx
        self.exercises = []
    }
}

