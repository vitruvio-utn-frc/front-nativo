import Foundation

/// Staff authoring operations: exercise catalog and training plan structure.
public extension TrainingService {
    // MARK: - Exercises

    func listExerciseTypes() async throws -> [ExerciseTypeDTO] {
        try await api.get("api/exercise-types")
    }

    func createExercise(_ request: ExerciseRequest) async throws -> ExerciseDTO {
        try await api.post("api/exercises", body: request)
    }

    func updateExercise(id: String, _ request: ExerciseRequest) async throws -> ExerciseDTO {
        try await api.put("api/exercises/\(id)", body: request)
    }

    func deleteExercise(id: String) async throws {
        try await api.delete("api/exercises/\(id)")
    }

    // MARK: - Plans

    func createPlan(_ request: TrainingPlanRequest) async throws -> TrainingPlanDTO {
        try await api.post("api/training-plans", body: request)
    }

    func updatePlan(id: String, _ request: TrainingPlanRequest) async throws -> TrainingPlanDTO {
        try await api.put("api/training-plans/\(id)", body: request)
    }

    func deletePlan(id: String) async throws {
        try await api.delete("api/training-plans/\(id)")
    }

    // MARK: - Structure

    func deleteSession(id: String) async throws {
        try await api.delete("api/training-sessions/\(id)")
    }

    func updateExecution(id: String, _ request: CreateExerciseExecutionRequest) async throws -> ExerciseExecutionDTO {
        try await api.put("api/exercise-executions/\(id)", body: request)
    }

    func deleteExecution(id: String) async throws {
        try await api.delete("api/exercise-executions/\(id)")
    }

    func updateSet(id: String, _ request: CreateExerciseSetRequest) async throws -> ExerciseSetDTO {
        try await api.put("api/exercise-sets/\(id)", body: request)
    }

    func deleteSet(id: String) async throws {
        try await api.delete("api/exercise-sets/\(id)")
    }
}
