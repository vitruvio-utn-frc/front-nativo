import Foundation

/// Where a persisted `caloriesBurnedInTotal` came from. Kept on device only: the API has no field for it.
public enum CalorieSource: String, Codable, Sendable {
    case healthkit
    case estimated
}

/// kcal rules for a completed exercise (see `training-calories` spec).
public enum TrainingCalories {
    /// `Exercise.CaloriesBurnRate` is entered by staff as kcal per repetition.
    public static func estimate(burnRatePerRep: Double?, prescribedReps: [Int]) -> Double {
        guard let burnRatePerRep, burnRatePerRep > 0 else { return 0 }
        return burnRatePerRep * Double(prescribedReps.reduce(0, +))
    }

    /// Active energy accumulated between two readings of the same workout.
    public static func measured(start: Double?, end: Double?) -> Double? {
        guard let start, let end else { return nil }
        return max(0, end - start)
    }
}

/// One prescribed exercise of the active session plus what the client has done on it so far.
public struct ActiveExerciseProgress: Codable, Equatable, Sendable, Identifiable, Hashable {
    /// Prescribed `ExerciseExecution` id.
    public var id: String
    public var exerciseId: String
    public var name: String
    public var prescribedReps: [Int]
    public var caloriesBurnRate: Double?
    public var videoUrl: String?
    public var doneSetIndexes: [Int]
    /// First set marked as done (or the end of the previous exercise).
    public var startedAt: Date?
    /// Workout active-energy reading when the first set was marked.
    public var energyAtStart: Double?
    public var completedAt: Date?
    public var kcal: Double?
    public var kcalSource: CalorieSource?

    public init(
        id: String,
        exerciseId: String,
        name: String,
        prescribedReps: [Int],
        caloriesBurnRate: Double? = nil,
        videoUrl: String? = nil,
        doneSetIndexes: [Int] = [],
        startedAt: Date? = nil,
        energyAtStart: Double? = nil,
        completedAt: Date? = nil,
        kcal: Double? = nil,
        kcalSource: CalorieSource? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.name = name
        self.prescribedReps = prescribedReps
        self.caloriesBurnRate = caloriesBurnRate
        self.videoUrl = videoUrl
        self.doneSetIndexes = doneSetIndexes
        self.startedAt = startedAt
        self.energyAtStart = energyAtStart
        self.completedAt = completedAt
        self.kcal = kcal
        self.kcalSource = kcalSource
    }

    public var isCompleted: Bool { completedAt != nil }
    public var setCount: Int { prescribedReps.count }
    public var doneSetCount: Int { doneSetIndexes.count }
}

/// Durable state of the training run in progress: one prescribed `TrainingSession` being executed.
/// Mirrored to the Watch through Watch Connectivity, which is why it is a plain `Codable` value.
public struct ActiveTrainingSessionSnapshot: Codable, Equatable, Sendable {
    /// Bumped when the shape changes; older persisted/received values are discarded.
    public static let currentVersion = 2

    public var version: Int
    /// The prescribed session being followed (read-only for the client).
    public var trainingSessionId: String
    /// Stable on-device id of the `TrainingSessionCompletion`; the server id is unknown until it syncs.
    public var completionLocalId: String
    public var completionServerId: String?
    /// The run is only written to the API once its first exercise is completed.
    public var completionQueued: Bool
    public var planId: String?
    public var planName: String?
    public var sessionLabel: String?
    public var startedAt: Date
    /// Last active-energy reading seen at an exercise boundary.
    public var energyCheckpoint: Double?
    public var exercises: [ActiveExerciseProgress]

    public init(
        trainingSessionId: String,
        completionLocalId: String = UUID().uuidString,
        completionServerId: String? = nil,
        completionQueued: Bool = false,
        planId: String? = nil,
        planName: String? = nil,
        sessionLabel: String? = nil,
        startedAt: Date = Date(),
        energyCheckpoint: Double? = nil,
        exercises: [ActiveExerciseProgress] = []
    ) {
        self.version = Self.currentVersion
        self.trainingSessionId = trainingSessionId
        self.completionLocalId = completionLocalId
        self.completionServerId = completionServerId
        self.completionQueued = completionQueued
        self.planId = planId
        self.planName = planName
        self.sessionLabel = sessionLabel
        self.startedAt = startedAt
        self.energyCheckpoint = energyCheckpoint
        self.exercises = exercises
    }

    private enum CodingKeys: String, CodingKey {
        case version, trainingSessionId, completionLocalId, completionServerId, completionQueued, planId, planName
        case sessionLabel, startedAt, energyCheckpoint, exercises
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported active session version \(version)"
            )
        }
        self.version = version
        trainingSessionId = try container.decode(String.self, forKey: .trainingSessionId)
        completionLocalId = try container.decode(String.self, forKey: .completionLocalId)
        completionServerId = try container.decodeIfPresent(String.self, forKey: .completionServerId)
        // Runs saved before this flag existed were always written at start.
        completionQueued = try container.decodeIfPresent(Bool.self, forKey: .completionQueued) ?? true
        planId = try container.decodeIfPresent(String.self, forKey: .planId)
        planName = try container.decodeIfPresent(String.self, forKey: .planName)
        sessionLabel = try container.decodeIfPresent(String.self, forKey: .sessionLabel)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        energyCheckpoint = try container.decodeIfPresent(Double.self, forKey: .energyCheckpoint)
        exercises = try container.decode([ActiveExerciseProgress].self, forKey: .exercises)
    }

    public var executionCount: Int { exercises.count }
    public var completedExerciseCount: Int { exercises.filter(\.isCompleted).count }
    /// Sets the client has marked as done across all exercises.
    public var setCount: Int { exercises.reduce(0) { $0 + $1.doneSetCount } }
    public var totalKcal: Double { exercises.compactMap(\.kcal).reduce(0, +) }

    public func exercise(id: String) -> ActiveExerciseProgress? {
        exercises.first { $0.id == id }
    }

    /// Marks or unmarks one prescribed set. The first mark starts the exercise and records the energy reading.
    /// Returns `false` when nothing changed (unknown exercise/set, or the exercise is already completed).
    @discardableResult
    public mutating func setSet(
        executionId: String,
        index: Int,
        done: Bool,
        at date: Date = Date(),
        energyKcal: Double? = nil
    ) -> Bool {
        guard let position = exercises.firstIndex(where: { $0.id == executionId }) else { return false }
        var exercise = exercises[position]
        guard !exercise.isCompleted, exercise.prescribedReps.indices.contains(index) else { return false }

        if done {
            guard !exercise.doneSetIndexes.contains(index) else { return false }
            exercise.doneSetIndexes.append(index)
            exercise.doneSetIndexes.sort()
            if exercise.startedAt == nil {
                exercise.startedAt = date
                exercise.energyAtStart = energyKcal
            }
        } else {
            guard exercise.doneSetIndexes.contains(index) else { return false }
            exercise.doneSetIndexes.removeAll { $0 == index }
            if exercise.doneSetIndexes.isEmpty {
                exercise.startedAt = nil
                exercise.energyAtStart = nil
            }
        }
        exercises[position] = exercise
        return true
    }

    /// Completes a prescribed exercise and attributes its kcal: measured when both energy readings exist,
    /// estimated from the exercise's burn rate otherwise. Returns the completed exercise, or `nil` when it
    /// is unknown or already completed.
    @discardableResult
    public mutating func completeExercise(
        executionId: String,
        at date: Date = Date(),
        energyKcal: Double? = nil
    ) -> ActiveExerciseProgress? {
        guard let position = exercises.firstIndex(where: { $0.id == executionId }),
              !exercises[position].isCompleted
        else { return nil }
        var exercise = exercises[position]

        let previousEnd = exercises.compactMap(\.completedAt).max()
        let start = min(exercise.startedAt ?? previousEnd ?? startedAt, date)
        let startEnergy = exercise.energyAtStart ?? energyCheckpoint

        if let measured = TrainingCalories.measured(start: startEnergy, end: energyKcal) {
            exercise.kcal = measured
            exercise.kcalSource = .healthkit
        } else {
            exercise.kcal = TrainingCalories.estimate(
                burnRatePerRep: exercise.caloriesBurnRate,
                prescribedReps: exercise.prescribedReps
            )
            exercise.kcalSource = .estimated
        }
        exercise.startedAt = start
        exercise.completedAt = date
        exercises[position] = exercise
        if let energyKcal { energyCheckpoint = energyKcal }
        return exercise
    }
}
