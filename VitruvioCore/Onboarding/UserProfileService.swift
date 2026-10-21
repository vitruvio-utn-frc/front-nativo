import Foundation

/// Matches backend `UpdateUserRequest` (full replace, same shape as create).
public struct UpdateUserRequest: Encodable, Sendable {
    public var idNumber: Int
    public var firstName: String
    public var lastName: String
    public var email: String
    public var photoUrl: String?
    public var height: Double
    public var weight: Double
    public var birthDate: Date
    public var genderId: Int

    public init(
        idNumber: Int,
        firstName: String,
        lastName: String,
        email: String,
        photoUrl: String? = nil,
        height: Double,
        weight: Double,
        birthDate: Date,
        genderId: Int
    ) {
        self.idNumber = idNumber
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.photoUrl = photoUrl
        self.height = height
        self.weight = weight
        self.birthDate = birthDate
        self.genderId = genderId
    }
}

extension UpdateUserRequest {
    private enum CodingKeys: String, CodingKey {
        case idNumber, firstName, lastName, email, photoUrl, height, weight, birthDate, genderId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(idNumber, forKey: .idNumber)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(email, forKey: .email)
        try container.encode(photoUrl, forKey: .photoUrl)
        try container.encode(height, forKey: .height)
        try container.encode(weight, forKey: .weight)
        try container.encode(BirthDateCoding.string(from: birthDate), forKey: .birthDate)
        try container.encode(genderId, forKey: .genderId)
    }
}

/// Reads and updates the authenticated user's API `User` profile.
public struct UserProfileService: Sendable {
    private let api: AuthenticatedAPIClient

    public init(api: AuthenticatedAPIClient) {
        self.api = api
    }

    public func loadUser(id: String) async throws -> UserDTO {
        try await api.get("api/users/\(id)")
    }

    public func updateUser(id: String, _ request: UpdateUserRequest) async throws -> UserDTO {
        try await api.put("api/users/\(id)", body: request)
    }

    public func loadGenders() async throws -> [GenderDTO] {
        try await api.get("api/genders")
    }
}
