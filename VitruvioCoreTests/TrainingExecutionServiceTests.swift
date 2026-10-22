import Foundation
import Testing
@testable import VitruvioCore

/// Services share one on-device file for the active run, so these tests run one at a time.
@MainActor
@Suite(.serialized)
struct TrainingExecutionServiceTests {
    private let session = PrescribedSession(id: "S1", label: "Sesión 1", exercises: [
        PrescribedExercise(id: "e1", exerciseId: "x1", name: "Banca", reps: [10, 10, 8], caloriesBurnRate: 0.5),
        PrescribedExercise(id: "e2", exerciseId: "x2", name: "Remo", reps: [12], caloriesBurnRate: 1),
    ])

    @MainActor
    private struct Fixture {
        let service: TrainingExecutionService
        let store: ActiveTrainingSessionStore
        let queue: FileOfflineQueue
        let server: StubServer
        let defaultsSuite: String
        let queueFile: String

        func tearDown() {
            store.clear()
            UserDefaults().removePersistentDomain(forName: defaultsSuite)
            QueueFixtures.remove(queueFile)
        }
    }

    private func makeFixture(online: Bool = true) -> Fixture {
        let suite = "test-service-\(UUID().uuidString)"
        let store = ActiveTrainingSessionStore(defaults: UserDefaults(suiteName: suite)!)
        store.clear()
        let (queue, file) = QueueFixtures.makeQueue()
        let server: StubServer
        if online {
            server = StubServer(QueueFixtures.acceptAll)
        } else {
            server = StubServer { _ in .unreachable }
        }
        let service = TrainingExecutionService(
            training: TrainingService(api: server.api),
            memberId: "m1",
            store: store,
            queue: queue
        )
        return Fixture(service: service, store: store, queue: queue, server: server, defaultsSuite: suite, queueFile: file)
    }

    // MARK: Starting

    @Test func startingWritesNothingAndMakesTheRunActive() throws {
        let f = makeFixture()
        defer { f.tearDown() }

        try f.service.start(planId: "P1", planName: "Plan", session: session)

        #expect(f.store.snapshot?.trainingSessionId == "S1")
        #expect(f.store.snapshot?.completionServerId == nil)
        #expect(f.queue.pendingCount == 0)
        #expect(f.server.requests.isEmpty)
    }

    @Test func aSecondRunCannotStartWhileOneIsActive() throws {
        let f = makeFixture()
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)

        #expect(throws: TrainingExecutionError.self) {
            try f.service.start(planId: "P1", planName: "Plan", session: session)
        }
    }

    @Test func markingSetsStaysOnTheDevice() throws {
        let f = makeFixture()
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)

        f.service.setSet(executionId: "e1", index: 0, done: true)
        f.service.setSet(executionId: "e1", index: 1, done: true)

        #expect(f.store.snapshot?.setCount == 2)
        #expect(f.queue.pendingCount == 0)
        #expect(f.server.requests.isEmpty)
    }

    // MARK: Recording

    @Test func theFirstCompletedExerciseRecordsTheRunWithItsRealStart() async throws {
        let f = makeFixture()
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)
        let startedAt = try #require(f.store.snapshot?.startedAt)

        try f.service.completeExercise(executionId: "e1")
        #expect(await waitUntil { f.queue.pendingCount == 0 })

        let requests = f.server.requests
        #expect(requests.map { "\($0.method) \($0.path)" } == [
            "POST /api/training-session-completions",
            "POST /api/exercise-completions",
        ])
        let sentStart = try #require(requests[0].json["startDate"] as? String)
        let formatter = ISO8601DateFormatter()
        let sentDate = try #require(formatter.date(from: sentStart))
        #expect(abs(sentDate.timeIntervalSince(startedAt)) < 1.5)
        #expect(requests[0].json["memberId"] as? String == "m1")
        #expect(requests[0].json["trainingPlanId"] as? String == "P1")
        #expect(requests[0].json["trainingSessionId"] as? String == "S1")
    }

    @Test func theServerIdArrivesOnTheActiveRunOnItsOwn() async throws {
        let f = makeFixture()
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)
        #expect(f.store.snapshot?.completionServerId == nil)

        try f.service.completeExercise(executionId: "e1")

        #expect(await waitUntil { f.store.snapshot?.completionServerId == "SRV-SESSION" })
    }

    @Test func theRunIsWrittenOnlyOnce() async throws {
        let f = makeFixture()
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)

        try f.service.completeExercise(executionId: "e1")
        try f.service.completeExercise(executionId: "e2")
        #expect(await waitUntil { f.queue.pendingCount == 0 })

        let creates = f.server.requests.filter { $0.path.hasSuffix("training-session-completions") && $0.method == "POST" }
        #expect(creates.count == 1)
        #expect(f.server.requests.filter { $0.path.hasSuffix("exercise-completions") }.count == 2)
    }

    @Test func endingWithoutCompletedExercisesWritesNothing() async throws {
        let f = makeFixture()
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)
        f.service.setSet(executionId: "e1", index: 0, done: true)

        try f.service.end()
        // Checked before any background flush can run: nothing may even be queued, because a queued
        // record the queue later discards as an orphan would hide the mistake.
        #expect(f.queue.pendingCount == 0)
        #expect(f.store.snapshot == nil)
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(f.queue.pendingCount == 0)
        #expect(f.server.requests.isEmpty)
    }

    @Test func endingARecordedRunClosesItWithAnEndDate() async throws {
        let f = makeFixture()
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)
        try f.service.completeExercise(executionId: "e1")
        try f.service.end()

        #expect(await waitUntil { f.queue.pendingCount == 0 })

        let last = try #require(f.server.requests.last)
        #expect(last.method == "PUT")
        #expect(last.path == "/api/training-session-completions/SRV-SESSION")
        #expect(last.json["endDate"] != nil)
        #expect(f.store.snapshot == nil)
    }

    // MARK: Offline

    @Test func aWholeRunDoneOfflineIsRecordedOnceTheNetworkReturns() async throws {
        let f = makeFixture(online: false)
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)
        try f.service.completeExercise(executionId: "e1")
        try f.service.completeExercise(executionId: "e2")
        try f.service.end()
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(f.queue.pendingCount == 4)

        f.server.respond(with: QueueFixtures.acceptAll)
        f.server.clearRequests()
        await f.service.flush()
        #expect(await waitUntil { f.queue.pendingCount == 0 })

        #expect(f.server.requests.map { "\($0.method) \($0.path)" } == [
            "POST /api/training-session-completions",
            "POST /api/exercise-completions",
            "POST /api/exercise-completions",
            "PUT /api/training-session-completions/SRV-SESSION",
        ])
    }

    // MARK: Calories

    @Test func estimatedKcalAreSentButTheirSourceIsNot() async throws {
        let f = makeFixture()
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)

        try f.service.completeExercise(executionId: "e1")   // 0.5 × (10 + 10 + 8) = 14
        try f.service.completeExercise(executionId: "e2")   // 1 × 12 = 12
        #expect(await waitUntil { f.queue.pendingCount == 0 })

        let kcal = f.server.requests
            .filter { $0.path.hasSuffix("exercise-completions") }
            .compactMap { $0.json["caloriesBurnedInTotal"] as? Double }
        #expect(kcal == [14, 12])
        #expect(f.server.requests.allSatisfy { !$0.bodyText.contains("estimated") && !$0.bodyText.contains("Source") })
    }

    // MARK: The prescription stays untouched

    @Test func nothingIsEverWrittenToThePrescription() async throws {
        let f = makeFixture()
        defer { f.tearDown() }
        try f.service.start(planId: "P1", planName: "Plan", session: session)
        f.service.setSet(executionId: "e1", index: 0, done: true)
        try f.service.completeExercise(executionId: "e1")
        try f.service.end()
        #expect(await waitUntil { f.queue.pendingCount == 0 })

        let touched = f.server.requests.filter {
            $0.path.contains("training-sessions") || $0.path.contains("exercise-executions") || $0.path.contains("exercise-sets")
        }
        #expect(touched.isEmpty)
    }
}
