import Foundation
import Testing
@testable import VitruvioCore

struct SnapshotCodingTests {
    private func decode(_ json: String) -> ActiveTrainingSessionSnapshot? {
        try? JSONDecoder().decode(ActiveTrainingSessionSnapshot.self, from: Data(json.utf8))
    }

    @Test func roundTripKeepsEverything() throws {
        var snapshot = ActiveTrainingSessionSnapshot(
            trainingSessionId: "S",
            completionServerId: "SRV",
            completionQueued: true,
            planId: "P",
            planName: "Plan",
            sessionLabel: "Sesión 1",
            exercises: [ActiveExerciseProgress(id: "e1", exerciseId: "x", name: "Banca", prescribedReps: [10, 8], videoUrl: "https://x.test/a.gif")]
        )
        snapshot.setSet(executionId: "e1", index: 0, done: true, energyKcal: 3)
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(ActiveTrainingSessionSnapshot.self, from: data) == snapshot)
    }

    @Test func formatBeforeTheVersionFieldIsRejected() {
        #expect(decode(#"{"sessionId":"x","startedAt":0,"executionCount":1,"setCount":1}"#) == nil)
    }

    @Test func unknownVersionIsRejected() {
        let json = #"{"version":99,"trainingSessionId":"S","completionLocalId":"L","startedAt":0,"exercises":[]}"#
        #expect(decode(json) == nil)
    }

    @Test func runsSavedBeforeTheQueuedFlagCountAsAlreadyWritten() {
        let json = #"{"version":2,"trainingSessionId":"S","completionLocalId":"L","startedAt":0,"exercises":[]}"#
        #expect(decode(json)?.completionQueued == true)
    }

    @Test func aNewRunIsNotWrittenYet() {
        #expect(ActiveTrainingSessionSnapshot(trainingSessionId: "S").completionQueued == false)
    }
}
