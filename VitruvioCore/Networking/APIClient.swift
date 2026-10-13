import Foundation

/// HTTP API seam. Bearer attachment and refresh land in `auth-keycloak`.
public protocol APIClient: Sendable {
    var baseURL: URL { get }
}

/// Minimal API client stub that exposes the configured base URL.
public struct StubAPIClient: APIClient {
    public let baseURL: URL

    public init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
    }
}
