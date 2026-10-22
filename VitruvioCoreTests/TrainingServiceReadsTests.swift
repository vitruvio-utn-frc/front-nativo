import Foundation
import Testing
@testable import VitruvioCore

struct TrainingServiceReadsTests {
    // MARK: Prescribed sessions

    private func prescriptionServer() -> StubServer {
        StubServer { request in
            switch request.path {
            case "/api/training-sessions":
                return .json(200, """
                [{"id":"S1","trainingPlanId":"P1"},{"id":"S2","trainingPlanId":"P1"},
                 {"id":"S3","trainingPlanId":"P1"},{"id":"S4","trainingPlanId":"P2"}]
                """)
            case "/api/exercise-executions":
                return .json(200, """
                [{"id":"X1","exerciseId":"E1","trainingSessionId":"S1"},
                 {"id":"X2","exerciseId":"E2","trainingSessionId":"S1"},
                 {"id":"X3","exerciseId":"E1","trainingSessionId":"S3"},
                 {"id":"X4","exerciseId":"E2","trainingSessionId":"S4"}]
                """)
            case "/api/exercise-sets":
                return .json(200, """
                [{"id":"T1","exerciseExecutionId":"X1","reps":10},{"id":"T2","exerciseExecutionId":"X1","reps":8},
                 {"id":"T3","exerciseExecutionId":"X2","reps":12},{"id":"T4","exerciseExecutionId":"X3","reps":5}]
                """)
            case "/api/exercises":
                return .json(200, """
                [{"id":"E1","name":"Banca","caloriesBurnRate":0.5,"videoUrl":"https://cdn.test/banca.gif"},
                 {"id":"E2","name":"Remo"}]
                """)
            default:
                return .json(404, "")
            }
        }
    }

    @Test func prescribedSessionsCarryRepsRateAndVideo() async throws {
        let server = prescriptionServer()

        let sessions = try await TrainingService(api: server.api).loadPrescribedSessions(planId: "P1")

        let first = try #require(sessions.first)
        #expect(first.id == "S1")
        #expect(first.exercises.map(\.name) == ["Banca", "Remo"])
        let banca = try #require(first.exercises.first { $0.id == "X1" })
        #expect(banca.reps.sorted() == [8, 10])
        #expect(banca.caloriesBurnRate == 0.5)
        #expect(banca.videoUrl == "https://cdn.test/banca.gif")
        #expect(first.exercises.first { $0.id == "X2" }?.videoUrl == nil)
    }

    @Test func sessionsWithoutExercisesAreLeftOutAndLabelsAreConsecutive() async throws {
        let server = StubServer { request in
            switch request.path {
            case "/api/training-sessions": return .json(200, #"[{"id":"EMPTY","trainingPlanId":"P1"},{"id":"S1","trainingPlanId":"P1"}]"#)
            case "/api/exercise-executions": return .json(200, #"[{"id":"X1","exerciseId":"E1","trainingSessionId":"S1"}]"#)
            case "/api/exercise-sets": return .json(200, "[]")
            case "/api/exercises": return .json(200, #"[{"id":"E1","name":"Banca"}]"#)
            default: return .json(404, "")
            }
        }

        let sessions = try await TrainingService(api: server.api).loadPrescribedSessions(planId: "P1")

        #expect(sessions.map(\.id) == ["S1"])
        #expect(sessions.first?.label == "Sesión 1")
    }

    @Test func severalPlansAreLoadedWithOneReadPerTable() async throws {
        let server = prescriptionServer()

        let byPlan = try await TrainingService(api: server.api).loadPrescribedSessions(planIds: ["P1", "P2"])

        #expect(byPlan["P1"]?.map(\.id) == ["S1", "S3"])
        #expect(byPlan["P2"]?.map(\.id) == ["S4"])
        #expect(server.requests.count == 4)
    }

    // MARK: Completions

    private let completionsJSON = """
    [{"id":"a","trainingSessionId":"S1","trainingSession":null,"memberId":"M1","trainingPlanId":"P1","startDate":"2026-10-20T10:00:00+00:00","endDate":"2026-10-20T10:30:00+00:00"},
     {"id":"b","trainingSessionId":"S2","memberId":"m1","trainingPlanId":"P2","startDate":"2026-10-22T10:00:00+00:00","endDate":null},
     {"id":"c","trainingSessionId":"S1","memberId":"M1","trainingPlanId":"P1","startDate":"2026-10-21T10:00:00+00:00","endDate":"2026-10-21T10:10:00+00:00"},
     {"id":"d","trainingSessionId":"S1","memberId":"OTHER","trainingPlanId":"P1","startDate":"2026-10-23T10:00:00+00:00"}]
    """

    @Test func historyIsTheClientsOwnRunsNewestFirst() async throws {
        let server = StubServer { _ in .json(200, completionsJSON) }

        let history = try await TrainingService(api: server.api).listCompletions(memberId: "m1")

        #expect(history.map(\.id) == ["b", "c", "a"])
    }

    @Test func historyCanBeNarrowedToOnePlan() async throws {
        let server = StubServer { _ in .json(200, completionsJSON) }

        let history = try await TrainingService(api: server.api).listCompletions(memberId: "M1", planId: "p1")

        #expect(history.map(\.id) == ["c", "a"])
    }

    @Test func completionDatesAndDurationDecode() async throws {
        let server = StubServer { _ in .json(200, completionsJSON) }

        let history = try await TrainingService(api: server.api).listCompletions(memberId: "M1", planId: "P1")
        let run = try #require(history.last)

        #expect(run.startDate != nil)
        #expect(run.duration == 1_800)
    }

    @Test func openRunHasNoDuration() async throws {
        let server = StubServer { _ in .json(200, completionsJSON) }

        let history = try await TrainingService(api: server.api).listCompletions(memberId: "m1")

        #expect(history.first { $0.id == "b" }?.duration == nil)
    }

    @Test func fractionalSecondsFromTheServerDecode() throws {
        let json = #"{"id":"a","trainingSessionId":"S","memberId":"M","startDate":"2026-10-21T10:00:00.1234567+00:00","endDate":"2026-10-21T10:45:30+00:00"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let run = try decoder.decode(TrainingSessionCompletionDTO.self, from: Data(json.utf8))

        #expect(run.startDate != nil)
        #expect(run.endDate != nil)
    }

    @Test func exerciseCompletionsOfARunAreOrderedByStart() async throws {
        let server = StubServer { _ in .json(200, """
        [{"id":"2","exerciseExecutionId":"X2","trainingSessionCompletionId":"A","startDate":"2026-10-21T10:20:00+00:00","caloriesBurnedInTotal":30},
         {"id":"1","exerciseExecutionId":"X1","trainingSessionCompletionId":"a","startDate":"2026-10-21T10:00:00+00:00","caloriesBurnedInTotal":20},
         {"id":"3","exerciseExecutionId":"X3","trainingSessionCompletionId":"B","startDate":"2026-10-21T10:10:00+00:00"},
         {"id":"4","exerciseExecutionId":"X4","trainingSessionCompletionId":null}]
        """) }

        let items = try await TrainingService(api: server.api).listExerciseCompletions(sessionCompletionId: "A")

        #expect(items.map(\.id) == ["1", "2"])
        #expect(items.compactMap(\.caloriesBurnedInTotal) == [20, 30])
    }
}
