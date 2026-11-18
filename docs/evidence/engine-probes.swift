import Foundation
let target = Target(weight: 60, repMin: 8, repMax: 12, sets: 3, phase: "HYP")
let rule = Rule(equipment: "barbell", barbellInc: 2.5, dbInc: 2, deloadPct: 0.10, missLimit: 3)
print("Empty logs next weight:", computeNextTargets(lastLogs: [], lastTarget: target, rule: rule, phase: "HYP", consecutiveMisses: 0, blockStartLoad: nil).weight as Any)
print("One of three sets next weight:", computeNextTargets(lastLogs: [SetLog(weight: 60, reps: 12, rir: 2)], lastTarget: target, rule: rule, phase: "HYP", consecutiveMisses: 0, blockStartLoad: nil).weight as Any)
print("Lower actual load next weight:", computeNextTargets(lastLogs: Array(repeating: SetLog(weight: 20, reps: 12, rir: 2), count: 3), lastTarget: target, rule: rule, phase: "HYP", consecutiveMisses: 0, blockStartLoad: nil).weight as Any)
print("Rowing zone success:", nextRowingPrescription(previous: "Zone2 26-30m", success: true))
print("Rowing zone failure:", nextRowingPrescription(previous: "Zone2 26-30m", success: false))
print("Phase empty history:", shouldSwitchPhase(history: [], currentPhase: "HYP", blockStartLoad: 60, currentLoad: 63))
let internalWeight = 60.0
print("Pounds display:", internalWeight * 2.20462, "saved kg:", internalWeight / 2.20462)
