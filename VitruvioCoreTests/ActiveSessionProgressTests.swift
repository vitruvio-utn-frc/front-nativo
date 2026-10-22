import Foundation
import Testing
@testable import VitruvioCore

struct ActiveSessionProgressTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func makeSnapshot() -> ActiveTrainingSessionSnapshot {
        ActiveTrainingSessionSnapshot(
            trainingSessionId: "S",
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            exercises: [
                ActiveExerciseProgress(id: "e1", exerciseId: "x1", name: "Banca", prescribedReps: [10, 10, 8], caloriesBurnRate: 0.5),
                ActiveExerciseProgress(id: "e2", exerciseId: "x2", name: "Remo", prescribedReps: [12]),
                ActiveExerciseProgress(id: "e3", exerciseId: "x3", name: "Sentadilla", prescribedReps: [10], caloriesBurnRate: 1),
            ]
        )
    }

    // MARK: Sets

    @Test func firstMarkedSetStartsTheExerciseAndRecordsEnergy() {
        var snapshot = makeSnapshot()
        let changed = snapshot.setSet(executionId: "e1", index: 0, done: true, at: t0, energyKcal: 10)
        #expect(changed)
        let exercise = snapshot.exercise(id: "e1")
        #expect(exercise?.startedAt == t0)
        #expect(exercise?.energyAtStart == 10)
        #expect(exercise?.doneSetIndexes == [0])
    }

    @Test func markingTheSameSetTwiceChangesNothing() {
        var snapshot = makeSnapshot()
        snapshot.setSet(executionId: "e1", index: 0, done: true, at: t0)
        let again = snapshot.setSet(executionId: "e1", index: 0, done: true, at: t0)
        #expect(!again)
        #expect(snapshot.exercise(id: "e1")?.doneSetCount == 1)
    }

    @Test func unknownExerciseOrOutOfRangeSetIsIgnored() {
        var snapshot = makeSnapshot()
        let unknownExercise = snapshot.setSet(executionId: "nope", index: 0, done: true)
        let outOfRange = snapshot.setSet(executionId: "e1", index: 9, done: true)
        #expect(!unknownExercise)
        #expect(!outOfRange)
        #expect(snapshot.setCount == 0)
    }

    @Test func unmarkingTheLastSetResetsTheStart() {
        var snapshot = makeSnapshot()
        snapshot.setSet(executionId: "e1", index: 0, done: true, at: t0, energyKcal: 10)
        snapshot.setSet(executionId: "e1", index: 0, done: false)
        #expect(snapshot.exercise(id: "e1")?.startedAt == nil)
        #expect(snapshot.exercise(id: "e1")?.energyAtStart == nil)
    }

    @Test func setsOfACompletedExerciseCannotChange() {
        var snapshot = makeSnapshot()
        snapshot.completeExercise(executionId: "e1", at: t0)
        let changed = snapshot.setSet(executionId: "e1", index: 0, done: true)
        #expect(!changed)
    }

    // MARK: Completing and calories

    @Test func completedExerciseUsesMeasuredEnergyBetweenReadings() throws {
        var snapshot = makeSnapshot()
        snapshot.setSet(executionId: "e1", index: 0, done: true, at: t0, energyKcal: 10)
        let result = snapshot.completeExercise(executionId: "e1", at: t0.addingTimeInterval(120), energyKcal: 52)
        let completed = try #require(result)
        #expect(completed.kcal == 42)
        #expect(completed.kcalSource == .healthkit)
        #expect(snapshot.energyCheckpoint == 52)
    }

    @Test func consecutiveExercisesDoNotDoubleCountEnergy() throws {
        var snapshot = makeSnapshot()
        snapshot.setSet(executionId: "e1", index: 0, done: true, at: t0, energyKcal: 10)
        let firstResult = snapshot.completeExercise(executionId: "e1", at: t0.addingTimeInterval(120), energyKcal: 52)
        // No set marked on the second exercise: it starts where the previous one ended.
        let secondResult = snapshot.completeExercise(executionId: "e2", at: t0.addingTimeInterval(300), energyKcal: 107)
        let first = try #require(firstResult)
        let second = try #require(secondResult)
        #expect(first.kcal == 42)
        #expect(second.kcal == 55)
        #expect(second.startedAt == t0.addingTimeInterval(120))
    }

    @Test func withoutReadingsTheEstimateUsesBurnRateTimesPrescribedReps() throws {
        var snapshot = makeSnapshot()
        let result = snapshot.completeExercise(executionId: "e3", at: t0)
        let completed = try #require(result)
        #expect(completed.kcal == 10)
        #expect(completed.kcalSource == .estimated)
    }

    @Test func missingBurnRateEstimatesZero() throws {
        var snapshot = makeSnapshot()
        let result = snapshot.completeExercise(executionId: "e2", at: t0)
        let completed = try #require(result)
        #expect(completed.kcal == 0)
        #expect(completed.kcalSource == .estimated)
    }

    @Test func completingTwiceOrUnknownReturnsNil() {
        var snapshot = makeSnapshot()
        snapshot.completeExercise(executionId: "e1", at: t0)
        let twice = snapshot.completeExercise(executionId: "e1", at: t0)
        let unknown = snapshot.completeExercise(executionId: "nope", at: t0)
        #expect(twice == nil)
        #expect(unknown == nil)
    }

    @Test func startNeverComesAfterTheEnd() throws {
        var snapshot = makeSnapshot()
        snapshot.setSet(executionId: "e1", index: 0, done: true, at: t0.addingTimeInterval(500))
        let result = snapshot.completeExercise(executionId: "e1", at: t0)
        let completed = try #require(result)
        let started = try #require(completed.startedAt)
        #expect(started <= t0)
    }

    @Test func sessionTotalIsTheSumOfItsExercises() {
        var snapshot = makeSnapshot()
        snapshot.setSet(executionId: "e1", index: 0, done: true, at: t0, energyKcal: 0)
        snapshot.completeExercise(executionId: "e1", at: t0.addingTimeInterval(60), energyKcal: 42)
        snapshot.completeExercise(executionId: "e2", at: t0.addingTimeInterval(120), energyKcal: 97)
        snapshot.completeExercise(executionId: "e3", at: t0.addingTimeInterval(180), energyKcal: nil)
        // 42 measured + 55 measured + 10 estimated
        #expect(snapshot.totalKcal == 107)
        #expect(snapshot.completedExerciseCount == 3)
    }
}
