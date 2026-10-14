import Foundation

/// Training reads/writes against the 2025 REST API.
public struct TrainingService: Sendable {
    public let api: AuthenticatedAPIClient

    public init(api: AuthenticatedAPIClient) {
        self.api = api
    }

    public func listPlans(forMemberId memberId: String) async throws -> [TrainingPlanDTO] {
        let all: [TrainingPlanDTO] = try await api.get("api/training-plans")
        return all
            .filter { $0.memberId.caseInsensitiveCompare(memberId) == .orderedSame }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func getPlan(id: String) async throws -> TrainingPlanDTO? {
        try await api.getOptional("api/training-plans/\(id)")
    }

    public func listSessions(forPlanId planId: String) async throws -> [TrainingSessionDTO] {
        let all: [TrainingSessionDTO] = try await api.get("api/training-sessions")
        return all.filter {
            ($0.trainingPlanId ?? "").caseInsensitiveCompare(planId) == .orderedSame
        }
    }

    public func createSession(planId: String) async throws -> TrainingSessionDTO {
        try await api.post(
            "api/training-sessions",
            body: CreateTrainingSessionRequest(trainingPlanId: planId)
        )
    }

    public func getSession(id: String) async throws -> TrainingSessionDTO? {
        try await api.getOptional("api/training-sessions/\(id)")
    }

    public func listExercises() async throws -> [ExerciseDTO] {
        try await api.get("api/exercises")
    }

    public func listExecutions(forSessionId sessionId: String) async throws -> [ExerciseExecutionDTO] {
        let all: [ExerciseExecutionDTO] = try await api.get("api/exercise-executions")
        return all.filter {
            ($0.trainingSessionId ?? "").caseInsensitiveCompare(sessionId) == .orderedSame
        }
    }

    public func createExecution(_ request: CreateExerciseExecutionRequest) async throws -> ExerciseExecutionDTO {
        try await api.post("api/exercise-executions", body: request)
    }

    public func listSets(forExecutionId executionId: String) async throws -> [ExerciseSetDTO] {
        let all: [ExerciseSetDTO] = try await api.get("api/exercise-sets")
        return all.filter {
            $0.exerciseExecutionId.caseInsensitiveCompare(executionId) == .orderedSame
        }
    }

    public func createSet(_ request: CreateExerciseSetRequest) async throws -> ExerciseSetDTO {
        try await api.post("api/exercise-sets", body: request)
    }

    public func createCompletion(_ request: CreateExerciseCompletionRequest) async throws -> ExerciseCompletionDTO {
        try await api.post("api/exercise-completions", body: request)
    }
}
