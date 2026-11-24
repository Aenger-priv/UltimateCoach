import XCTest
@testable import UltimateCoach

@MainActor
final class AdaptiveRestSimulationTests: XCTestCase {
    private struct RandomStream {
        var state: UInt64
        // SplitMix64. Use separate reproducible streams for outcomes and assignment.
        mutating func next() -> Double {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return Double((z ^ (z >> 31)) >> 11) / 9007199254740992.0
        }
    }

    private enum Scenario: String, CaseIterable {
        case helpfulLater, helpfulEarly, alwaysHelpful, alwaysHarmful, noEffect, smallBenefit

        func hitRates(context: Int) -> (offer: Double, usual: Double) {
            switch self {
            case .helpfulLater: context == 1 ? (0.8, 0.2) : (0.2, 0.8)
            case .helpfulEarly: context == 0 ? (0.8, 0.2) : (0.2, 0.8)
            case .alwaysHelpful: (0.8, 0.2)
            case .alwaysHarmful: (0.2, 0.8)
            case .noEffect: (0.5, 0.5)
            case .smallBenefit: (0.55, 0.5)
            }
        }
    }

    func testRepeatedDecisionsWithKnownContextSpecificRewards() {
        // Common potential outcomes for all policies; reveal only the chosen outcome to the learner.
        for scenario in Scenario.allCases {
            var adaptiveWins = 0
            var fixedOfferWins = 0
            var ordinaryWins = 0
            var offers = [0, 0]
            let worlds = 32
            let opportunities = 96
            for seed in 1...worlds {
                var rewards = RandomStream(state: UInt64(seed))
                var draws = RandomStream(state: UInt64(seed) ^ 0xC0AC_4E55_10A3_7700)
                var observations = [[AdaptiveRest.Observation](), []]
                for step in 0..<opportunities {
                    let context = step % 2
                    let rates = scenario.hitRates(context: context)
                    let latent = rewards.next()
                    let offerOutcome = latent < rates.offer
                    let usualOutcome = latent < rates.usual
                    let probability = AdaptiveRest.offerProbability(for: observations[context])
                    let offered = AdaptiveRest.selectOffer(probability: probability, draw: draws.next())
                    let observed = offered ? offerOutcome : usualOutcome
                    observations[context].append(.init(offered: offered, metTarget: observed))
                    if offered { offers[context] += 1 }
                    if observed { adaptiveWins += 1 }
                    if offerOutcome { fixedOfferWins += 1 }
                    if usualOutcome { ordinaryWins += 1 }
                }
            }
            let total = worlds * opportunities
            print("Rest simulation \(scenario.rawValue): N=\(total), hits adaptive/always/usual=" +
                  "\(adaptiveWins)/\(fixedOfferWins)/\(ordinaryWins), offers early/later=\(offers)")
            switch scenario {
            case .helpfulLater, .helpfulEarly:
                XCTAssertGreaterThan(adaptiveWins, max(fixedOfferWins, ordinaryWins))
                XCTAssertEqual(offers[1] > offers[0], scenario == .helpfulLater)
            case .alwaysHelpful, .alwaysHarmful:
                XCTAssertGreaterThan(adaptiveWins, min(fixedOfferWins, ordinaryWins))
                XCTAssertLessThan(adaptiveWins, max(fixedOfferWins, ordinaryWins))
                XCTAssertEqual(offers.reduce(0, +) > total / 2, scenario == .alwaysHelpful)
            case .noEffect:
                XCTAssertEqual(adaptiveWins, fixedOfferWins)
                XCTAssertEqual(adaptiveWins, ordinaryWins)
            case .smallBenefit:
                XCTAssertLessThan(offers.reduce(0, +), total / 2)
                XCTAssertTrue((ordinaryWins...fixedOfferWins).contains(adaptiveWins))
            }
        }
    }
}
