import Foundation

/// One exercise of a prescribed session: what the trainer asked for, read-only for the client.
public struct PrescribedExercise: Codable, Equatable, Sendable, Identifiable, Hashable {
    /// Prescribed `ExerciseExecution` id.
    public var id: String
    public var exerciseId: String
    public var name: String
    public var reps: [Int]
    public var caloriesBurnRate: Double?
    /// Instructions media (video, animated image or page) from the exercise catalog.
    public var videoUrl: String?

    public init(
        id: String,
        exerciseId: String,
        name: String,
        reps: [Int],
        caloriesBurnRate: Double? = nil,
        videoUrl: String? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.name = name
        self.reps = reps
        self.caloriesBurnRate = caloriesBurnRate
        self.videoUrl = videoUrl
    }
}

/// A prescribed `TrainingSession` of a plan with its exercises resolved.
/// The API gives sessions neither a name nor an order, so `label` is positional ("Sesión 2").
public struct PrescribedSession: Codable, Equatable, Sendable, Identifiable, Hashable {
    public var id: String
    public var label: String
    public var exercises: [PrescribedExercise]

    public init(id: String, label: String, exercises: [PrescribedExercise]) {
        self.id = id
        self.label = label
        self.exercises = exercises
    }

    /// Exercise names joined for list rows.
    public var summary: String {
        exercises.map(\.name).joined(separator: " · ")
    }

    /// Starting state of a run that follows this session.
    func makeProgress() -> [ActiveExerciseProgress] {
        exercises.map {
            ActiveExerciseProgress(
                id: $0.id,
                exerciseId: $0.exerciseId,
                name: $0.name,
                prescribedReps: $0.reps,
                caloriesBurnRate: $0.caloriesBurnRate,
                videoUrl: $0.videoUrl
            )
        }
    }
}

public extension TrainingService {
    /// Prescribed sessions of a plan, ready to follow. Sessions without exercises are left out.
    func loadPrescribedSessions(planId: String) async throws -> [PrescribedSession] {
        try await loadPrescribedSessions(planIds: [planId])[planId] ?? []
    }

    /// Prescribed sessions for several plans, keyed by plan id. Reads each table once
    /// instead of once per plan or session.
    func loadPrescribedSessions(planIds: [String]) async throws -> [String: [PrescribedSession]] {
        async let sessionsTask: [TrainingSessionDTO] = api.get("api/training-sessions")
        async let executionsTask: [ExerciseExecutionDTO] = api.get("api/exercise-executions")
        async let setsTask: [ExerciseSetDTO] = api.get("api/exercise-sets")
        async let exercisesTask = listExercises()
        let (allSessions, executions, sets, exercises) = try await (
            sessionsTask, executionsTask, setsTask, exercisesTask
        )

        let exerciseById = Dictionary(exercises.map { ($0.id.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let repsByExecution = Dictionary(grouping: sets, by: { $0.exerciseExecutionId.lowercased() })
        let executionsBySession = Dictionary(
            grouping: executions.filter { $0.trainingSessionId != nil },
            by: { $0.trainingSessionId!.lowercased() }
        )

        var result: [String: [PrescribedSession]] = [:]
        for planId in planIds {
            var sessions: [PrescribedSession] = []
            for session in allSessions where (session.trainingPlanId ?? "").caseInsensitiveCompare(planId) == .orderedSame {
                let rows = (executionsBySession[session.id.lowercased()] ?? []).map { execution -> PrescribedExercise in
                    let exercise = exerciseById[execution.exerciseId.lowercased()]
                    return PrescribedExercise(
                        id: execution.id,
                        exerciseId: execution.exerciseId,
                        name: exercise?.name ?? execution.exerciseId,
                        reps: (repsByExecution[execution.id.lowercased()] ?? []).map(\.reps),
                        caloriesBurnRate: exercise?.caloriesBurnRate,
                        videoUrl: exercise?.videoUrl
                    )
                }
                guard !rows.isEmpty else { continue }
                sessions.append(PrescribedSession(id: session.id, label: "Sesión \(sessions.count + 1)", exercises: rows))
            }
            result[planId] = sessions
        }
        return result
    }
}
