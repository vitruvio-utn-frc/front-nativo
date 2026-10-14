import Foundation

public struct TrainingPlanDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let memberId: String
    public let trainerId: String?
    public let name: String
    public let description: String?
    public let duration: String?
    public let startDate: Date?
    public let endDate: Date?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        memberId = try container.decodeLosslessString(forKey: DynamicCodingKeys("memberId"))
        trainerId = try? container.decodeLosslessString(forKey: DynamicCodingKeys("trainerId"))
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? id
        description = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("description"))
        duration = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("duration"))
        startDate = try? container.decodeIfPresent(Date.self, forKey: DynamicCodingKeys("startDate"))
        endDate = try? container.decodeIfPresent(Date.self, forKey: DynamicCodingKeys("endDate"))
    }

    public var durationLabel: String {
        guard let duration, !duration.isEmpty else { return "" }
        let dayPart = duration.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first
            .map(String.init) ?? duration
        if let days = Int(dayPart) {
            return days == 1 ? "1 day" : "\(days) days"
        }
        return duration
    }
}

public struct TrainingSessionDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let trainingPlanId: String?
    public let trainingPlanTemplateId: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        trainingPlanId = try? container.decodeLosslessString(forKey: DynamicCodingKeys("trainingPlanId"))
        trainingPlanTemplateId = try? container.decodeLosslessString(forKey: DynamicCodingKeys("trainingPlanTemplateId"))
    }
}

public struct CreateTrainingSessionRequest: Encodable, Sendable {
    public var trainingPlanId: String?
    public var trainingPlanTemplateId: String?

    public init(trainingPlanId: String? = nil, trainingPlanTemplateId: String? = nil) {
        self.trainingPlanId = trainingPlanId
        self.trainingPlanTemplateId = trainingPlanTemplateId
    }
}

public struct ExerciseDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String?
    public let caloriesBurnRate: Double?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? id
        description = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("description"))
        caloriesBurnRate = try? container.decodeIfPresent(Double.self, forKey: DynamicCodingKeys("caloriesBurnRate"))
    }
}

public struct ExerciseExecutionDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let exerciseId: String
    public let trainingSessionId: String?
    public let notes: String?
    public let duration: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        exerciseId = try container.decodeLosslessString(forKey: DynamicCodingKeys("exerciseId"))
        trainingSessionId = try? container.decodeLosslessString(forKey: DynamicCodingKeys("trainingSessionId"))
        notes = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("notes"))
        duration = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("duration"))
    }
}

public struct CreateExerciseExecutionRequest: Codable, Sendable {
    public var exerciseId: String
    public var trainingSessionId: String?
    public var duration: String?
    public var notes: String?

    public init(exerciseId: String, trainingSessionId: String? = nil, duration: String? = nil, notes: String? = nil) {
        self.exerciseId = exerciseId
        self.trainingSessionId = trainingSessionId
        self.duration = duration
        self.notes = notes
    }
}

public struct ExerciseSetDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let exerciseExecutionId: String
    public let reps: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        exerciseExecutionId = try container.decodeLosslessString(forKey: DynamicCodingKeys("exerciseExecutionId"))
        reps = container.decodeLosslessIntIfPresent(forKey: DynamicCodingKeys("reps")) ?? 0
    }
}

public struct CreateExerciseSetRequest: Codable, Sendable {
    public var exerciseExecutionId: String
    public var reps: Int

    public init(exerciseExecutionId: String, reps: Int) {
        self.exerciseExecutionId = exerciseExecutionId
        self.reps = reps
    }
}

public struct ExerciseCompletionDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let exerciseExecutionId: String
    public let startDate: Date?
    public let endDate: Date?
    public let caloriesBurnedInTotal: Double?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        exerciseExecutionId = try container.decodeLosslessString(forKey: DynamicCodingKeys("exerciseExecutionId"))
        startDate = try? container.decodeIfPresent(Date.self, forKey: DynamicCodingKeys("startDate"))
        endDate = try? container.decodeIfPresent(Date.self, forKey: DynamicCodingKeys("endDate"))
        caloriesBurnedInTotal = try? container.decodeIfPresent(Double.self, forKey: DynamicCodingKeys("caloriesBurnedInTotal"))
    }
}

public struct CreateExerciseCompletionRequest: Codable, Sendable {
    public var exerciseExecutionId: String
    public var trainingSessionCompletionId: String?
    public var startDate: Date
    public var endDate: Date
    public var caloriesBurnedInTotal: Double

    public init(
        exerciseExecutionId: String,
        trainingSessionCompletionId: String? = nil,
        startDate: Date,
        endDate: Date,
        caloriesBurnedInTotal: Double = 0
    ) {
        self.exerciseExecutionId = exerciseExecutionId
        self.trainingSessionCompletionId = trainingSessionCompletionId
        self.startDate = startDate
        self.endDate = endDate
        self.caloriesBurnedInTotal = caloriesBurnedInTotal
    }
}

/// Durable snapshot of the active training session (synced via Watch Connectivity).
public struct ActiveTrainingSessionSnapshot: Codable, Equatable, Sendable {
    public var sessionId: String
    public var planId: String?
    public var planName: String?
    public var startedAt: Date
    public var executionCount: Int
    public var setCount: Int

    public init(
        sessionId: String,
        planId: String? = nil,
        planName: String? = nil,
        startedAt: Date = Date(),
        executionCount: Int = 0,
        setCount: Int = 0
    ) {
        self.sessionId = sessionId
        self.planId = planId
        self.planName = planName
        self.startedAt = startedAt
        self.executionCount = executionCount
        self.setCount = setCount
    }
}
