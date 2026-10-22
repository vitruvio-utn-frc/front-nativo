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
    public let exerciseTypeId: Int?
    public let machineTypeId: Int?
    public let photoUrl: String?
    public let videoUrl: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? id
        description = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("description"))
        caloriesBurnRate = try? container.decodeIfPresent(Double.self, forKey: DynamicCodingKeys("caloriesBurnRate"))
        exerciseTypeId = container.decodeLosslessIntIfPresent(forKey: DynamicCodingKeys("exerciseTypeId"))
        machineTypeId = container.decodeLosslessIntIfPresent(forKey: DynamicCodingKeys("machineTypeId"))
        photoUrl = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("photoUrl"))
        videoUrl = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("videoUrl"))
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
    public let trainingSessionCompletionId: String?
    public let startDate: Date?
    public let endDate: Date?
    public let caloriesBurnedInTotal: Double?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        exerciseExecutionId = try container.decodeLosslessString(forKey: DynamicCodingKeys("exerciseExecutionId"))
        trainingSessionCompletionId = try? container.decodeLosslessString(forKey: DynamicCodingKeys("trainingSessionCompletionId"))
        startDate = container.decodeFlexibleDateIfPresent(forKey: DynamicCodingKeys("startDate"))
        endDate = container.decodeFlexibleDateIfPresent(forKey: DynamicCodingKeys("endDate"))
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

/// A recorded training run: what the client actually did for one prescribed `TrainingSession`.
public struct TrainingSessionCompletionDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let trainingSessionId: String
    public let memberId: String
    public let trainingPlanId: String?
    public let startDate: Date?
    public let endDate: Date?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        trainingSessionId = try container.decodeLosslessString(forKey: DynamicCodingKeys("trainingSessionId"))
        memberId = try container.decodeLosslessString(forKey: DynamicCodingKeys("memberId"))
        trainingPlanId = try? container.decodeLosslessString(forKey: DynamicCodingKeys("trainingPlanId"))
        startDate = container.decodeFlexibleDateIfPresent(forKey: DynamicCodingKeys("startDate"))
        endDate = container.decodeFlexibleDateIfPresent(forKey: DynamicCodingKeys("endDate"))
    }

    /// Wall-clock length once the run has ended.
    public var duration: TimeInterval? {
        guard let startDate, let endDate else { return nil }
        return max(0, endDate.timeIntervalSince(startDate))
    }
}

public struct CreateTrainingSessionCompletionRequest: Codable, Sendable {
    public var trainingSessionId: String
    public var memberId: String
    public var trainingPlanId: String?
    public var startDate: Date?
    public var endDate: Date?

    public init(
        trainingSessionId: String,
        memberId: String,
        trainingPlanId: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.trainingSessionId = trainingSessionId
        self.memberId = memberId
        self.trainingPlanId = trainingPlanId
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// `PUT` replaces every field, so an update carries the same shape as a create.
public typealias UpdateTrainingSessionCompletionRequest = CreateTrainingSessionCompletionRequest

extension KeyedDecodingContainer where K == DynamicCodingKeys {
    /// ISO 8601 date that tolerates the fractional seconds ASP.NET emits for sub-second values.
    func decodeFlexibleDateIfPresent(forKey key: DynamicCodingKeys) -> Date? {
        if let date = try? decode(Date.self, forKey: key) {
            return date
        }
        guard let string = try? decode(String.self, forKey: key) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        // .NET writes 7 fractional digits; ISO8601DateFormatter only accepts up to 3.
        if let dot = string.firstIndex(of: "."),
           let zone = string[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let digits = string[string.index(after: dot)..<zone].prefix(3)
            return formatter.date(from: String(string[..<dot]) + "." + digits + String(string[zone...]))
        }
        return nil
    }
}
