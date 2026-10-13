import Foundation

public struct AuthTokens: Codable, Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String?
    public var idToken: String?
    public var tokenType: String
    public var expiresAt: Date?
    public var subject: String?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        idToken: String? = nil,
        tokenType: String = "Bearer",
        expiresAt: Date? = nil,
        subject: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.subject = subject
    }

    public var isAccessTokenExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt.addingTimeInterval(-30)
    }
}
