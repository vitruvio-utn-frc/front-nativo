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

    public func getSession(id: String) async throws -> TrainingSessionDTO? {
        try await api.getOptional("api/training-sessions/\(id)")
    }

    /// The client's own recorded runs, newest first. Optionally narrowed to one plan.
    public func listCompletions(memberId: String, planId: String? = nil) async throws -> [TrainingSessionCompletionDTO] {
        let all: [TrainingSessionCompletionDTO] = try await api.get("api/training-session-completions")
        return all
            .filter { $0.memberId.caseInsensitiveCompare(memberId) == .orderedSame }
            .filter { completion in
                guard let planId else { return true }
                return (completion.trainingPlanId ?? "").caseInsensitiveCompare(planId) == .orderedSame
            }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    public func listExerciseCompletions(sessionCompletionId: String) async throws -> [ExerciseCompletionDTO] {
        let all: [ExerciseCompletionDTO] = try await api.get("api/exercise-completions")
        return all
            .filter { ($0.trainingSessionCompletionId ?? "").caseInsensitiveCompare(sessionCompletionId) == .orderedSame }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
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

    public func listExecutions(withIds ids: Set<String>) async throws -> [ExerciseExecutionDTO] {
        let wanted = Set(ids.map { $0.lowercased() })
        let all: [ExerciseExecutionDTO] = try await api.get("api/exercise-executions")
        return all.filter { wanted.contains($0.id.lowercased()) }
    }

    public func listSets(forExecutionId executionId: String) async throws -> [ExerciseSetDTO] {
        let all: [ExerciseSetDTO] = try await api.get("api/exercise-sets")
        return all.filter {
            $0.exerciseExecutionId.caseInsensitiveCompare(executionId) == .orderedSame
        }
    }

    public func createCompletion(_ request: CreateExerciseCompletionRequest) async throws -> ExerciseCompletionDTO {
        try await api.post("api/exercise-completions", body: request)
    }
}
