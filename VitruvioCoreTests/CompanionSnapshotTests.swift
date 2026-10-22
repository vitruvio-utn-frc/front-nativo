import Foundation
import Testing
@testable import VitruvioCore

@MainActor
struct CompanionSnapshotTests {
    private let training = ActiveTrainingSessionSnapshot(
        trainingSessionId: "S",
        completionServerId: "SRV",
        planId: "P",
        planName: "Plan",
        sessionLabel: "Sesión 1",
        exercises: [ActiveExerciseProgress(id: "e1", exerciseId: "x", name: "Banca", prescribedReps: [10, 8], doneSetIndexes: [0])]
    )
    private let plans = [
        CompanionPlanItem(id: "P", name: "Plan", sessions: [CompanionSessionItem(id: "S", label: "Sesión 1", summary: "Banca", exerciseCount: 1)]),
    ]

    private func encoded() -> [String: Any] {
        WatchConnectivityBridge.encodeContext(CompanionSyncSnapshot(hasAuth: true, userId: "u", training: training, plans: plans))
    }

    @Test func theWireVersionIsStamped() {
        #expect(encoded()["v"] as? Int == WatchConnectivityBridge.wireVersion)
    }

    @Test func theDictionaryIsSafeForWatchConnectivity() {
        #expect(PropertyListSerialization.propertyList(encoded() as NSDictionary, isValidFor: .binary))
    }

    @Test func theActiveRunSurvivesTheWire() throws {
        let json = try #require(encoded()["trainingJSON"] as? String)

        let decoded = try JSONDecoder().decode(ActiveTrainingSessionSnapshot.self, from: Data(json.utf8))

        #expect(decoded == training)
        #expect(decoded.completionServerId == "SRV")
    }

    @Test func plansWithTheirSessionsSurviveTheWire() throws {
        let json = try #require(encoded()["plansJSON"] as? String)

        #expect(try JSONDecoder().decode([CompanionPlanItem].self, from: Data(json.utf8)) == plans)
    }

    @Test func aPlanWithoutSessionsFieldStillDecodes() throws {
        let decoded = try JSONDecoder().decode([CompanionPlanItem].self, from: Data(#"[{"id":"P","name":"Plan"}]"#.utf8))

        #expect(decoded.first?.sessions == [])
    }

    @Test func noActiveRunMeansNoTrainingPayload() {
        let dictionary = WatchConnectivityBridge.encodeContext(CompanionSyncSnapshot(hasAuth: true))

        #expect(dictionary["trainingJSON"] == nil)
    }

    @Test func convenienceAccessorsReadFromTheActiveRun() {
        let snapshot = CompanionSyncSnapshot(hasAuth: true, training: training)

        #expect(snapshot.trainingSessionId == "S")
        #expect(snapshot.trainingPlanName == "Plan")
        #expect(snapshot.trainingSnapshot == training)
    }

    @Test func aSessionItemSummarisesThePrescription() {
        let prescribed = PrescribedSession(id: "S", label: "Sesión 2", exercises: [
            PrescribedExercise(id: "a", exerciseId: "1", name: "Banca", reps: [10]),
            PrescribedExercise(id: "b", exerciseId: "2", name: "Remo", reps: [12]),
        ])

        let item = CompanionSessionItem(prescribed)

        #expect(item.label == "Sesión 2")
        #expect(item.summary == "Banca · Remo")
        #expect(item.exerciseCount == 2)
    }
}
