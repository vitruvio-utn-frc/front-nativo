import Foundation

public struct CreateUserGymRoleRequest: Encodable, Sendable {
    public var userId: String
    public var gymId: String
    public var roleId: Int

    public init(userId: String, gymId: String, roleId: Int) {
        self.userId = userId
        self.gymId = gymId
        self.roleId = roleId
    }
}

public struct CompanyDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? id
    }
}

public struct CreateCompanyRequest: Encodable, Sendable {
    public var name: String
    public var description: String?
    public var phoneNumber: String?
    public var email: String?
    public var photoUrl: String?

    public init(name: String, description: String? = nil, phoneNumber: String? = nil, email: String? = nil) {
        self.name = name
        self.description = description
        self.phoneNumber = phoneNumber
        self.email = email
        self.photoUrl = nil
    }
}

public struct CreateGymRequest: Encodable, Sendable {
    public var name: String
    public var companyId: String
    public var address: String
    public var zipCode: String
    public var city: String
    public var state: String
    public var phoneNumber: String?
    public var email: String?
    public var photoUrl: String?

    public init(
        name: String,
        companyId: String,
        address: String,
        zipCode: String,
        city: String,
        state: String,
        phoneNumber: String? = nil,
        email: String? = nil
    ) {
        self.name = name
        self.companyId = companyId
        self.address = address
        self.zipCode = zipCode
        self.city = city
        self.state = state
        self.phoneNumber = phoneNumber
        self.email = email
        self.photoUrl = nil
    }
}

/// Matches backend `UpdateGymRequest` (same shape as create).
public struct UpdateGymRequest: Encodable, Sendable {
    public var name: String
    public var companyId: String
    public var address: String
    public var zipCode: String
    public var city: String
    public var state: String
    public var phoneNumber: String?
    public var email: String?
    public var photoUrl: String?

    public init(
        name: String,
        companyId: String,
        address: String,
        zipCode: String,
        city: String,
        state: String,
        phoneNumber: String? = nil,
        email: String? = nil
    ) {
        self.name = name
        self.companyId = companyId
        self.address = address
        self.zipCode = zipCode
        self.city = city
        self.state = state
        self.phoneNumber = phoneNumber
        self.email = email
        self.photoUrl = nil
    }

    public init(from gym: GymDTO, companyId: String) {
        self.init(
            name: gym.name,
            companyId: companyId,
            address: gym.address ?? "",
            zipCode: gym.zipCode ?? "",
            city: gym.city ?? "",
            state: gym.state ?? "",
            phoneNumber: gym.phoneNumber,
            email: gym.email
        )
    }
}

public struct MembershipDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String?
    public let price: Double
    public let duration: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? id
        description = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("description"))
        if let double = try? container.decode(Double.self, forKey: DynamicCodingKeys("price")) {
            price = double
        } else if let string = try? container.decode(String.self, forKey: DynamicCodingKeys("price")),
                  let double = Double(string) {
            price = double
        } else {
            price = 0
        }
        duration = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("duration"))
    }

    /// Days parsed from ASP.NET TimeSpan (`"30.00:00:00"` → 30).
    public var durationDays: Int? {
        guard let duration, !duration.isEmpty else { return nil }
        let dayPart = duration.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first
            .map(String.init) ?? duration
        if let days = Int(dayPart) { return days }
        // `"00:00:00"`-style (under one day) or other formats
        if duration.contains(":"), !duration.contains(".") { return 0 }
        return nil
    }

    public var durationLabel: String {
        guard let days = durationDays else {
            return duration ?? ""
        }
        return days == 1 ? "1 day" : "\(days) days"
    }
}

public struct CreateMembershipRequest: Encodable, Sendable {
    public var name: String
    public var description: String?
    public var price: Double
    /// ASP.NET TimeSpan string, e.g. `"30.00:00:00"` for 30 days.
    public var duration: String

    public init(name: String, description: String? = nil, price: Double, durationDays: Int) {
        self.name = name
        self.description = description
        self.price = price
        self.duration = "\(max(durationDays, 1)).00:00:00"
    }
}

public struct GymMembershipLinkDTO: Codable, Sendable, Identifiable, Hashable {
    public var id: String { "\(gymId)|\(membershipId)" }
    public let gymId: String
    public let membershipId: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        gymId = try container.decodeLosslessString(forKey: DynamicCodingKeys("gymId"))
        membershipId = try container.decodeLosslessString(forKey: DynamicCodingKeys("membershipId"))
    }
}

public struct UserMembershipDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let memberId: String
    public let membershipId: String
    public let startDate: Date?
    public let endDate: Date?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        memberId = try container.decodeLosslessString(forKey: DynamicCodingKeys("memberId"))
        membershipId = try container.decodeLosslessString(forKey: DynamicCodingKeys("membershipId"))
        startDate = try? container.decodeIfPresent(Date.self, forKey: DynamicCodingKeys("startDate"))
        endDate = try? container.decodeIfPresent(Date.self, forKey: DynamicCodingKeys("endDate"))
    }

    public var isActive: Bool {
        let now = Date()
        if let startDate, startDate > now { return false }
        if let endDate, endDate < now { return false }
        return true
    }
}

public struct CreateUserMembershipRequest: Encodable, Sendable {
    public var memberId: String
    public var membershipId: String
    public var startDate: Date
    public var endDate: Date

    public init(memberId: String, membershipId: String, startDate: Date, endDate: Date) {
        self.memberId = memberId
        self.membershipId = membershipId
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct CreateGymMembershipLinkRequest: Encodable, Sendable {
    public var gymId: String
    public var membershipId: String

    public init(gymId: String, membershipId: String) {
        self.gymId = gymId
        self.membershipId = membershipId
    }
}

public struct MachineTypeDTO: Codable, Sendable, Identifiable, Hashable {
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

public struct CreateMachineTypeRequest: Encodable, Sendable {
    public var name: String
    public var description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct UpdateMachineTypeRequest: Encodable, Sendable {
    public var name: String
    public var description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct MachineDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let machineTypeId: Int?
    public let brand: String?
    public let model: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        machineTypeId = container.decodeLosslessIntIfPresent(forKey: DynamicCodingKeys("machineTypeId"))
        brand = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("brand"))
        model = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("model"))
    }

    public var displayName: String {
        [brand, model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

public struct CreateMachineRequest: Encodable, Sendable {
    public var machineTypeId: Int
    public var brand: String
    public var model: String
    public var purchaseDate: Date
    public var lastServiceDate: Date?
    public var photoUrl: String?

    public init(
        machineTypeId: Int,
        brand: String,
        model: String,
        purchaseDate: Date = Date(),
        lastServiceDate: Date? = nil,
        photoUrl: String? = nil
    ) {
        self.machineTypeId = machineTypeId
        self.brand = brand
        self.model = model
        self.purchaseDate = purchaseDate
        self.lastServiceDate = lastServiceDate
        self.photoUrl = photoUrl
    }
}

public struct ActivityTypeDTO: Codable, Sendable, Identifiable, Hashable {
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

public struct CreateActivityTypeRequest: Encodable, Sendable {
    public var name: String
    public var description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct ActivityDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let activityTypeId: Int?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        name = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys("name")) ?? id
        activityTypeId = container.decodeLosslessIntIfPresent(forKey: DynamicCodingKeys("activityTypeId"))
    }
}

public struct CreateActivityRequest: Encodable, Sendable {
    public var name: String
    public var description: String?
    public var activityTypeId: Int

    public init(name: String, description: String? = nil, activityTypeId: Int) {
        self.name = name
        self.description = description
        self.activityTypeId = activityTypeId
    }
}

public struct AppointmentDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let gymId: String
    public let memberId: String?
    public let activityId: String
    public let startDate: Date?
    public let endDate: Date?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        gymId = try container.decodeLosslessString(forKey: DynamicCodingKeys("gymId"))
        memberId = try? container.decodeLosslessString(forKey: DynamicCodingKeys("memberId"))
        activityId = try container.decodeLosslessString(forKey: DynamicCodingKeys("activityId"))
        startDate = try container.decodeIfPresent(Date.self, forKey: DynamicCodingKeys("startDate"))
        endDate = try container.decodeIfPresent(Date.self, forKey: DynamicCodingKeys("endDate"))
    }
}

public struct CreateAppointmentRequest: Encodable, Sendable {
    public var gymId: String
    public var memberId: String?
    public var activityId: String
    public var startDate: Date
    public var endDate: Date

    public init(gymId: String, memberId: String? = nil, activityId: String, startDate: Date, endDate: Date) {
        self.gymId = gymId
        self.memberId = memberId
        self.activityId = activityId
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// User row for admin lists, with roles in the active gym.
public struct AdminDirectoryUser: Identifiable, Hashable, Sendable {
    public let user: UserDTO
    public let rolesInGym: [AppRole]
    public let isPending: Bool

    public var id: String { user.id }
}
