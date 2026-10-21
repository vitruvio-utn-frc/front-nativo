import Foundation

public struct ExerciseTypeDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let description: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = container.decodeLosslessIntIfPresent(forKey: DynamicCodingKeys("id")) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? String(id)
        description = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("description"))
    }
}

/// Matches backend `CreateExerciseRequest` / `UpdateExerciseRequest` (same shape).
public struct ExerciseRequest: Encodable, Sendable {
    public var name: String
    public var description: String?
    public var exerciseTypeId: Int
    public var machineTypeId: Int?
    public var photoUrl: String?
    public var videoUrl: String?
    public var caloriesBurnRate: Double

    public init(
        name: String,
        description: String? = nil,
        exerciseTypeId: Int,
        machineTypeId: Int? = nil,
        photoUrl: String? = nil,
        videoUrl: String? = nil,
        caloriesBurnRate: Double
    ) {
        self.name = name
        self.description = description
        self.exerciseTypeId = exerciseTypeId
        self.machineTypeId = machineTypeId
        self.photoUrl = photoUrl
        self.videoUrl = videoUrl
        self.caloriesBurnRate = caloriesBurnRate
    }
}

/// Matches backend `CreateTrainingPlanRequest` / `UpdateTrainingPlanRequest` (same shape).
public struct TrainingPlanRequest: Encodable, Sendable {
    public var memberId: String
    public var trainerId: String?
    public var name: String
    public var description: String?
    /// ASP.NET TimeSpan string, e.g. `"30.00:00:00"` for 30 days.
    public var duration: String
    public var startDate: Date?
    public var endDate: Date?

    public init(
        memberId: String,
        trainerId: String? = nil,
        name: String,
        description: String? = nil,
        durationDays: Int,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.memberId = memberId
        self.trainerId = trainerId
        self.name = name
        self.description = description
        self.duration = "\(max(durationDays, 1)).00:00:00"
        self.startDate = startDate
        self.endDate = endDate
    }
}

public extension TrainingPlanDTO {
    /// Days parsed from the ASP.NET TimeSpan `duration` (`"30.00:00:00"` → 30).
    var durationDays: Int? {
        guard let duration, !duration.isEmpty else { return nil }
        let dayPart = duration.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first
            .map(String.init) ?? duration
        return Int(dayPart)
    }
}

public extension ExerciseExecutionDTO {
    /// Request that re-sends this execution with a different `notes` (backend `PUT` is a full replace).
    func updateRequest(notes: String?) -> CreateExerciseExecutionRequest {
        CreateExerciseExecutionRequest(
            exerciseId: exerciseId,
            trainingSessionId: trainingSessionId,
            duration: duration,
            notes: notes
        )
    }
}
