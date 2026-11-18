import Foundation

// Stored weights and progression increments always use kilograms.
enum WeightUnit {
    static let poundsPerKilogram = 2.2046226218

    static func display(_ kilograms: Double, useKilograms: Bool) -> Double {
        useKilograms ? kilograms : kilograms * poundsPerKilogram
    }

    static func kilograms(_ value: Double, useKilograms: Bool) -> Double {
        useKilograms ? value : value / poundsPerKilogram
    }

    static func formatted(_ kilograms: Double, useKilograms: Bool) -> String {
        let value = display(kilograms, useKilograms: useKilograms)
        return value.formatted(.number.precision(.fractionLength(0...1))) + (useKilograms ? " kg" : " lb")
    }
}
