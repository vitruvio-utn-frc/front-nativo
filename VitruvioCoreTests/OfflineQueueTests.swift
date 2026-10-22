import Foundation
import Testing
@testable import VitruvioCore

/// Helpers shared by the queue and service tests.
enum QueueFixtures {
    static func makeQueue() -> (queue: FileOfflineQueue, fileName: String) {
        let fileName = "test-queue-\(UUID().uuidString).json"
        return (FileOfflineQueue(fileName: fileName), fileName)
    }

    static func remove(_ fileName: String) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: caches.appending(path: fileName))
    }

    static func sessionRequest() -> CreateTrainingSessionCompletionRequest {
        .init(trainingSessionId: "s", memberId: "m", trainingPlanId: "p", startDate: Date())
    }

    static func exerciseRequest(_ execution: String) -> CreateExerciseCompletionRequest {
        .init(exerciseExecutionId: execution, startDate: Date(), endDate: Date(), caloriesBurnedInTotal: 5)
    }

    /// Accepts everything: creates answer with a server id, updates answer 200.
    static let acceptAll: StubServer.Handler = { request in
        if request.method == "POST", request.path.hasSuffix("training-session-completions") {
            return .json(201, #"{"id":"SRV-SESSION"}"#)
        }
        if request.method == "POST", request.path.hasSuffix("exercise-completions") {
            return .json(201, "{\"id\":\"SRV-EX-\(UUID().uuidString)\"}")
        }
        if request.method == "PUT", request.path.contains("training-session-completions/") {
            return .json(200, #"{"id":"SRV-SESSION"}"#)
        }
        return .json(404, "")
    }

    /// A whole run: start, two exercises, end.
    static func enqueueFullRun(on queue: FileOfflineQueue, localId: String = "L-S") throws {
        try queue.enqueueEncoded(.createSessionCompletion, value: QueuedSessionCompletion(localId: localId, request: sessionRequest()))
        try queue.enqueueEncoded(.createExerciseCompletion, value: QueuedExerciseCompletion(localId: "L-E1", sessionCompletionLocalId: localId, request: exerciseRequest("e1")))
        try queue.enqueueEncoded(.createExerciseCompletion, value: QueuedExerciseCompletion(localId: "L-E2", sessionCompletionLocalId: localId, request: exerciseRequest("e2")))
        try queue.enqueueEncoded(.finishSessionCompletion, value: QueuedFinishSessionCompletion(sessionCompletionLocalId: localId, request: sessionRequest()))
    }
}

struct OfflineQueueTests {
    @Test func aWholeRunQueuedOfflineIsSentInOrderOnceBackOnline() async throws {
        let (queue, file) = QueueFixtures.makeQueue()
        defer { QueueFixtures.remove(file) }
        let server = StubServer { _ in .unreachable }
        try QueueFixtures.enqueueFullRun(on: queue)

        let offline = await queue.flush(using: server.api)
        #expect(offline.sent == 0)
        #expect(offline.discarded.isEmpty)
        #expect(queue.pendingCount == 4)

        server.clearRequests()
        server.respond(with: QueueFixtures.acceptAll)
        let online = await queue.flush(using: server.api)

        #expect(online.sent == 4)
        #expect(queue.pendingCount == 0)
        let sent = server.requests
        #expect(sent.map { "\($0.method) \($0.path)" } == [
            "POST /api/training-session-completions",
            "POST /api/exercise-completions",
            "POST /api/exercise-completions",
            "PUT /api/training-session-completions/SRV-SESSION",
        ])
        // Exercise completions point at the server id, not the on-device one.
        #expect(sent[1].json["trainingSessionCompletionId"] as? String == "SRV-SESSION")
        #expect(sent[2].json["trainingSessionCompletionId"] as? String == "SRV-SESSION")
        #expect(queue.serverId(forLocalId: "L-S") == "SRV-SESSION")
    }

    @Test func rejectedRecordIsDroppedAndDoesNotBlockTheRest() async throws {
        let (queue, file) = QueueFixtures.makeQueue()
        defer { QueueFixtures.remove(file) }
        let server = StubServer { request in
            if request.json["exerciseExecutionId"] as? String == "bad" { return .json(400, "bad fk") }
            return QueueFixtures.acceptAll(request)
        }
        try queue.enqueueEncoded(.createSessionCompletion, value: QueuedSessionCompletion(localId: "L-S", request: QueueFixtures.sessionRequest()))
        try queue.enqueueEncoded(.createExerciseCompletion, value: QueuedExerciseCompletion(localId: "BAD", sessionCompletionLocalId: "L-S", request: QueueFixtures.exerciseRequest("bad")))
        try queue.enqueueEncoded(.createExerciseCompletion, value: QueuedExerciseCompletion(localId: "GOOD", sessionCompletionLocalId: "L-S", request: QueueFixtures.exerciseRequest("good")))

        let result = await queue.flush(using: server.api)

        #expect(result.sent == 2)
        #expect(result.discarded.count == 1)
        #expect(queue.pendingCount == 0)
    }

    @Test(arguments: [500, 503, 408, 429])
    func retryableStatusKeepsEverythingQueued(status: Int) async throws {
        let (queue, file) = QueueFixtures.makeQueue()
        defer { QueueFixtures.remove(file) }
        let server = StubServer { _ in .json(status, "try later") }
        try QueueFixtures.enqueueFullRun(on: queue)

        let result = await queue.flush(using: server.api)

        #expect(result.sent == 0)
        #expect(result.discarded.isEmpty)
        #expect(queue.pendingCount == 4)
    }

    @Test func rejectedSessionDropsItsDependents() async throws {
        let (queue, file) = QueueFixtures.makeQueue()
        defer { QueueFixtures.remove(file) }
        let server = StubServer { _ in .json(400, "nope") }
        try QueueFixtures.enqueueFullRun(on: queue)

        let result = await queue.flush(using: server.api)

        #expect(result.sent == 0)
        #expect(result.discarded.count == 4)
        #expect(queue.pendingCount == 0)
    }

    @Test func concurrentFlushesSendEachRecordOnce() async throws {
        let (queue, file) = QueueFixtures.makeQueue()
        defer { QueueFixtures.remove(file) }
        let server = StubServer(QueueFixtures.acceptAll)
        try queue.enqueueEncoded(.createSessionCompletion, value: QueuedSessionCompletion(localId: "L-S", request: QueueFixtures.sessionRequest()))
        let api = server.api

        async let a = queue.flush(using: api)
        async let b = queue.flush(using: api)
        async let c = queue.flush(using: api)
        _ = await (a, b, c)

        #expect(server.requests.filter { $0.method == "POST" }.count == 1)
    }

    @Test func aResponseMissingFieldsDoesNotUndoASuccessfulWrite() async throws {
        let (queue, file) = QueueFixtures.makeQueue()
        defer { QueueFixtures.remove(file) }
        // Only the id comes back: the queue must not need anything else.
        let server = StubServer(QueueFixtures.acceptAll)
        try QueueFixtures.enqueueFullRun(on: queue)

        let result = await queue.flush(using: server.api)

        #expect(result.sent == 4)
        #expect(result.discarded.isEmpty)
    }

    @Test func resolvedIdsSurviveARestart() async throws {
        let (queue, file) = QueueFixtures.makeQueue()
        defer { QueueFixtures.remove(file) }
        let server = StubServer(QueueFixtures.acceptAll)
        try queue.enqueueEncoded(.createSessionCompletion, value: QueuedSessionCompletion(localId: "L-S", request: QueueFixtures.sessionRequest()))
        await queue.flush(using: server.api)

        let reopened = FileOfflineQueue(fileName: file)

        #expect(reopened.serverId(forLocalId: "L-S") == "SRV-SESSION")
    }

    @Test func fileInTheOldFormatIsIgnored() throws {
        let file = "test-queue-\(UUID().uuidString).json"
        defer { QueueFixtures.remove(file) }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try Data(#"[{"id":"1","kind":"createExerciseSet","payload":"e30=","enqueuedAt":0}]"#.utf8)
            .write(to: caches.appending(path: file))

        #expect(FileOfflineQueue(fileName: file).pendingCount == 0)
    }

    @Test func unknownKindIsDroppedButValidRecordsStay() throws {
        let file = "test-queue-\(UUID().uuidString).json"
        defer { QueueFixtures.remove(file) }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let json = #"{"version":2,"records":[{"id":"1","kind":"createExerciseSet","payload":"e30=","enqueuedAt":0},{"id":"2","kind":"createSessionCompletion","payload":"e30=","enqueuedAt":0}],"idMap":[]}"#
        try Data(json.utf8).write(to: caches.appending(path: file))

        #expect(FileOfflineQueue(fileName: file).pendingCount == 1)
    }
}

struct CalorieSourceStoreTests {
    @Test func theSourceMovesFromTheLocalIdToTheServerId() throws {
        let suite = "test-calories-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        CalorieSourceStore.record(id: "L1", source: .estimated, defaults: defaults)
        CalorieSourceStore.rekey(from: "L1", to: "SRV1", defaults: defaults)

        #expect(CalorieSourceStore.source(forCompletionId: "SRV1", defaults: defaults) == .estimated)
        #expect(CalorieSourceStore.source(forCompletionId: "L1", defaults: defaults) == nil)
    }

    @Test func unknownCompletionHasNoSource() throws {
        let suite = "test-calories-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(CalorieSourceStore.source(forCompletionId: "nope", defaults: defaults) == nil)
    }
}
