import Foundation

/// One `UserGymRole` row enriched with display names for gym/role.
public struct GymMembership: Equatable, Identifiable, Sendable, Hashable {
    public var id: String { "\(userId)|\(gymId)|\(roleId)" }

    public let userId: String
    public let gymId: String
    public let gymName: String
    public let roleId: Int
    public let roleName: String
    public let role: AppRole?

    public init(
        userId: String,
        gymId: String,
        gymName: String,
        roleId: Int,
        roleName: String,
        role: AppRole?
    ) {
        self.userId = userId
        self.gymId = gymId
        self.gymName = gymName
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

public struct GymDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? id
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
