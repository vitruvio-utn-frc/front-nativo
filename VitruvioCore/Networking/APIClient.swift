import Foundation

public enum APIClientError: Error, Equatable, Sendable {
    case invalidResponse
    case unauthorized
    case httpStatus(Int)
}

public protocol APIClient: Sendable {
    var baseURL: URL { get }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public protocol AccessTokenProviding: Sendable {
    func accessTokenForRequest() async throws -> String?
    func refreshAccessTokenForRequest() async throws -> String?
}

/// URLSession API client that attaches Bearer tokens and retries once after a 401 refresh.
public final class AuthenticatedAPIClient: APIClient, Sendable {
    public let baseURL: URL
    private let session: URLSession
    private let tokenProvider: AccessTokenProviding

    public init(
        baseURL: URL = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        tokenProvider: AccessTokenProviding
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var authorized = request
        if authorized.url == nil {
            authorized.url = baseURL
        }
        if let token = try await tokenProvider.accessTokenForRequest() {
            authorized.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: authorized)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard http.statusCode == 401 else {
            return (data, http)
        }

        guard let refreshed = try await tokenProvider.refreshAccessTokenForRequest() else {
            throw APIClientError.unauthorized
        }

        var retry = request
        if retry.url == nil {
            retry.url = baseURL
        }
        retry.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
        let (retryData, retryResponse) = try await session.data(for: retry)
        guard let retryHTTP = retryResponse as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        return (retryData, retryHTTP)
    }
}

/// Minimal API client stub that exposes the configured base URL.
public struct StubAPIClient: APIClient {
    public let baseURL: URL

    public init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw APIClientError.unauthorized
    }
}
