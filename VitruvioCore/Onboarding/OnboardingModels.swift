import Foundation

public struct GenderDTO: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        if let name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) {
            self.name = name
        } else if let description = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("description")) {
            self.name = description
        } else {
            self.name = id
        }
    }
}

/// Matches backend `CreateUserRequest` (camelCase JSON).
public struct CreateUserRequest: Encodable, Sendable {
    public var idNumber: Int
    public var firstName: String
    public var lastName: String
    public var email: String
    public var height: Double
    public var weight: Double
    public var birthDate: Date
    public var genderId: Int
    public var photoUrl: String?

    public init(
        idNumber: Int,
        firstName: String,
        lastName: String,
        email: String,
        height: Double,
        weight: Double,
        birthDate: Date,
        genderId: Int,
        photoUrl: String? = nil
    ) {
        self.idNumber = idNumber
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.height = height
        self.weight = weight
        self.birthDate = birthDate
        self.genderId = genderId
        self.photoUrl = photoUrl
    }
}

public struct UserDTO: Codable, Sendable {
    public let id: String
    public let email: String?
    public let firstName: String?
    public let lastName: String?
    public let idNumber: Int?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        email = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("email"))
        firstName = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("firstName"))
        lastName = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("lastName"))
        idNumber = container.decodeLosslessIntIfPresent(forKey: DynamicCodingKeys("idNumber"))
    }
}

/// Matches backend `CreateTenantRequest`.
public struct CreateTenantRequest: Encodable, Sendable {
    public var id: String
    public var userId: String
    public var description: String

    public init(id: String, userId: String, description: String = "keycloak") {
        self.id = id
        self.userId = userId
        self.description = description
    }
}

public struct TenantDTO: Codable, Sendable {
    public let id: String
    public let userId: String
    public let description: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        userId = try container.decodeLosslessString(forKey: DynamicCodingKeys("userId"))
        description = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("description"))
    }
}

/// Backend `UserGymRole` uses a composite key (no singular `id`).
public struct UserGymRoleDTO: Codable, Sendable, Identifiable {
    public var id: String { "\(userId)|\(gymId)|\(roleId)" }
    public let userId: String
    public let gymId: String
    public let roleId: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        userId = try container.decodeLosslessString(forKey: DynamicCodingKeys("userId"))
        gymId = try container.decodeLosslessString(forKey: DynamicCodingKeys("gymId"))
        roleId = try container.decodeLosslessString(forKey: DynamicCodingKeys("roleId"))
    }
}

public struct ProfilePrefill: Equatable, Sendable {
    public var email: String
    public var firstName: String
    public var lastName: String

    public init(email: String = "", firstName: String = "", lastName: String = "") {
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
    }

    public init(claims: OIDCClaims) {
        email = claims.email ?? ""
        if let given = claims.givenName, let family = claims.familyName {
            firstName = given
            lastName = family
        } else if let name = claims.name {
            let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
            firstName = parts.first ?? ""
            lastName = parts.count > 1 ? parts[1] : ""
        } else {
            firstName = claims.givenName ?? ""
            lastName = claims.familyName ?? ""
        }
    }
}

public enum OnboardingGate: Equatable, Sendable {
    case needsOnboarding(ProfilePrefill)
    case pendingApproval(userId: String)
    /// User has at least one gym role — gym-context-and-roles can take over.
    case ready(userId: String)
}

public enum OnboardingError: Error, Equatable, Sendable {
    case missingSubject
    case validation(String)
    case apiMessage(status: Int, message: String)
    case unexpected
}

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

extension KeyedDecodingContainer where K == DynamicCodingKeys {
    /// Decodes JSON string or number ids without throwing on type mismatch.
    func decodeLosslessString(forKey key: DynamicCodingKeys) throws -> String {
        if let string = try? decode(String.self, forKey: key) {
            return string
        }
        if let int = try? decode(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try? decode(Double.self, forKey: key), double.rounded() == double {
            return String(Int(double))
        }
        throw DecodingError.keyNotFound(
            key,
            .init(codingPath: codingPath, debugDescription: "Missing or invalid \(key.stringValue)")
        )
    }

    func decodeLosslessIntIfPresent(forKey key: DynamicCodingKeys) -> Int? {
        if let int = try? decode(Int.self, forKey: key) {
            return int
        }
        if let string = try? decode(String.self, forKey: key) {
            return Int(string)
        }
        return nil
    }
}
