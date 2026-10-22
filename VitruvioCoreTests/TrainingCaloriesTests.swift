import Foundation
import Testing
@testable import VitruvioCore

struct TrainingCaloriesTests {
    @Test func estimateMultipliesRatePerRepByPrescribedReps() {
        #expect(TrainingCalories.estimate(burnRatePerRep: 0.5, prescribedReps: [10, 10, 8]) == 14)
    }

    @Test(arguments: [
        (nil as Double?, [10]),
        (0.0 as Double?, [10]),
        (-1.0 as Double?, [10]),
        (0.5 as Double?, [Int]()),
    ])
    func estimateIsZeroWithoutUsableRateOrReps(rate: Double?, reps: [Int]) {
        #expect(TrainingCalories.estimate(burnRatePerRep: rate, prescribedReps: reps) == 0)
    }

    @Test func measuredIsTheEnergyAccumulatedBetweenReadings() {
        #expect(TrainingCalories.measured(start: 10, end: 52) == 42)
    }

    @Test func measuredNeedsBothReadings() {
        #expect(TrainingCalories.measured(start: nil, end: 52) == nil)
        #expect(TrainingCalories.measured(start: 10, end: nil) == nil)
    }

    @Test func measuredNeverGoesNegative() {
        #expect(TrainingCalories.measured(start: 50, end: 40) == 0)
    }
}
