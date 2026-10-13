import Foundation

public enum KeycloakAuthError: Error, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case missingAccessToken
    case missingRefreshToken
    case cancelled
    case notAuthenticated
}

struct TokenResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let tokenType: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

/// Talks to Keycloak token endpoints (code exchange + refresh). Presentation lives in the iOS shell.
public final class KeycloakTokenService: Sendable {
    private let session: URLSession
    private let configuration: OIDCConfiguration

    public struct OIDCConfiguration: Sendable {
        public var clientID: String
        public var redirectURI: URL
        public var tokenEndpoint: URL
        public var authorizationEndpoint: URL
        public var endSessionEndpoint: URL
        public var scopes: [String]

        public init(
            clientID: String = AppConfig.keycloakClientID,
            redirectURI: URL = AppConfig.keycloakRedirectURI,
            tokenEndpoint: URL = AppConfig.keycloakTokenEndpoint,
            authorizationEndpoint: URL = AppConfig.keycloakAuthorizationEndpoint,
            endSessionEndpoint: URL = AppConfig.keycloakEndSessionEndpoint,
            scopes: [String] = AppConfig.keycloakScopes
        ) {
            self.clientID = clientID
            self.redirectURI = redirectURI
            self.tokenEndpoint = tokenEndpoint
            self.authorizationEndpoint = authorizationEndpoint
            self.endSessionEndpoint = endSessionEndpoint
            self.scopes = scopes
        }
    }

    public init(
        configuration: OIDCConfiguration = OIDCConfiguration(),
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    public func makeAuthorizationURL(state: String, codeChallenge: String) throws -> URL {
        var components = URLComponents(url: configuration.authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let url = components?.url else { throw KeycloakAuthError.invalidURL }
        return url
    }

    public func exchangeAuthorizationCode(_ code: String, codeVerifier: String) async throws -> AuthTokens {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "grant_type": "authorization_code",
            "client_id": configuration.clientID,
            "code": code,
            "redirect_uri": configuration.redirectURI.absoluteString,
            "code_verifier": codeVerifier,
        ])
        return try await performTokenRequest(request)
    }

    public func refreshTokens(using refreshToken: String) async throws -> AuthTokens {
        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "grant_type": "refresh_token",
            "client_id": configuration.clientID,
            "refresh_token": refreshToken,
        ])
        return try await performTokenRequest(request)
    }

    public func endSessionURL(idTokenHint: String?) -> URL? {
        var components = URLComponents(url: configuration.endSessionEndpoint, resolvingAgainstBaseURL: false)
        var items = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "post_logout_redirect_uri", value: configuration.redirectURI.absoluteString),
        ]
        if let idTokenHint {
            items.append(URLQueryItem(name: "id_token_hint", value: idTokenHint))
        }
        components?.queryItems = items
        return components?.url
    }

    private func performTokenRequest(_ request: URLRequest) async throws -> AuthTokens {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KeycloakAuthError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw KeycloakAuthError.httpStatus(http.statusCode)
        }

        let dto = try JSONDecoder().decode(TokenResponseDTO.self, from: data)
        guard !dto.accessToken.isEmpty else { throw KeycloakAuthError.missingAccessToken }

        let expiresAt = dto.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
        let subject = JWTPayload.subject(from: dto.idToken ?? dto.accessToken)
        return AuthTokens(
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
            idToken: dto.idToken,
            tokenType: dto.tokenType ?? "Bearer",
            expiresAt: expiresAt,
            subject: subject
        )
    }

    private func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: ":#[]@!$&'()*+,;="))
        let body = fields
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }
}

enum JWTPayload {
    static func subject(from jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String
        else {
            return nil
        }
        return sub
    }
}
