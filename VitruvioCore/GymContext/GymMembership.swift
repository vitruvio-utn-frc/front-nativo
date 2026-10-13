import Foundation

/// One `UserGymRole` row enriched with display names for gym/role.
public struct GymMembership: Equatable, Identifiable, Sendable, Hashable {
    public var id: String { "\(userId)|\(gymId)|\(roleId)" }

    public let userId: String
    public let gymId: String
    public let gymName: String
    public let companyId: String?
    public let roleId: Int
    public let roleName: String
    public let role: AppRole?

    public init(
        userId: String,
        gymId: String,
        gymName: String,
        companyId: String? = nil,
        roleId: Int,
        roleName: String,
        role: AppRole?
    ) {
        self.userId = userId
        self.gymId = gymId
        self.gymName = gymName
        self.companyId = companyId
        self.roleId = roleId
        self.roleName = roleName
        self.role = role
    }

    public var selection: GymRoleSelection {
        GymRoleSelection(gymID: gymId, roleID: String(roleId))
    }

    public var displayTitle: String {
        "\(gymName) · \(roleName)"
    }
}

public struct GymDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let companyId: String?
    public let address: String?
    public let zipCode: String?
    public let city: String?
    public let state: String?
    public let phoneNumber: String?
    public let email: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? id
        companyId = try? container.decodeLosslessString(forKey: DynamicCodingKeys("companyId"))
        address = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("address"))
        zipCode = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("zipCode"))
        city = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("city"))
        state = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("state"))
        phoneNumber = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("phoneNumber"))
        email = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("email"))
    }

    public var locationLine: String {
        [city, state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

public struct RoleDTO: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        if let int = container.decodeLosslessIntIfPresent(forKey: DynamicCodingKeys("id")) {
            id = int
        } else {
            throw DecodingError.keyNotFound(
                DynamicCodingKeys("id"),
                .init(codingPath: container.codingPath, debugDescription: "Missing role id")
            )
        }
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? String(id)
        description = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("description"))
    }
}
