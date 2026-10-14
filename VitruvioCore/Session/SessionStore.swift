import Foundation

public enum AuthSessionState: Equatable, Sendable {
    case unauthenticated
    case authenticated(AuthTokens)
}

/// Auth/session seam backed by Keychain + Keycloak token APIs.
public protocol SessionStore: AnyObject, Sendable {
    var hasSession: Bool { get }
    var subject: String? { get }
    var currentTokens: AuthTokens? { get }
}

/// Coordinates local session lifecycle. Watch tokens are delivered via Watch Connectivity.
public final class SessionController: SessionStore, AccessTokenProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let tokenStore: KeychainTokenStore
    private let tokenService: KeycloakTokenService
    private var tokens: AuthTokens?
    private var refreshTask: Task<AuthTokens, Error>?

    public init(
        tokenStore: KeychainTokenStore = KeychainTokenStore(),
        tokenService: KeycloakTokenService = KeycloakTokenService()
    ) {
        self.tokenStore = tokenStore
        self.tokenService = tokenService
    }

    public var hasSession: Bool {
        lock.lock()
        defer { lock.unlock() }
        return tokens != nil
    }

    public var subject: String? {
        lock.lock()
        defer { lock.unlock() }
        return tokens?.subject
    }

    public var currentTokens: AuthTokens? {
        lock.lock()
        defer { lock.unlock() }
        return tokens
    }

    public func state() -> AuthSessionState {
        lock.lock()
        defer { lock.unlock() }
        guard let tokens else { return .unauthenticated }
        return .authenticated(tokens)
    }

    public func applyLogin(_ tokens: AuthTokens) throws {
        lock.lock()
        self.tokens = tokens
        lock.unlock()
        // Persistence is best-effort — in-memory session must succeed for Watch companion.
        try? tokenStore.save(tokens)
    }

    public func restoreSession() async throws -> AuthSessionState {
        guard let stored = try tokenStore.load() else {
            setTokens(nil)
            return .unauthenticated
        }

        if stored.isAccessTokenExpired {
            guard let refreshToken = stored.refreshToken else {
                try tokenStore.delete()
                setTokens(nil)
                return .unauthenticated
            }
            let refreshed = try await tokenService.refreshTokens(using: refreshToken)
            setTokens(refreshed)
            try tokenStore.save(refreshed)
            return .authenticated(refreshed)
        }

        setTokens(stored)
        return .authenticated(stored)
    }

    public func logout() throws {
        setTokens(nil)
        try tokenStore.delete()
    }

    public func validAccessToken() async throws -> String {
        if let tokens = currentTokens, !tokens.isAccessTokenExpired {
            return tokens.accessToken
        }
        let refreshed = try await refreshAccessToken()
        return refreshed.accessToken
    }

    public func refreshAccessToken() async throws -> AuthTokens {
        lock.lock()
        if let refreshTask {
            lock.unlock()
            return try await refreshTask.value
        }

        let task = Task<AuthTokens, Error> { [tokenStore, tokenService] in
            let existing = try tokenStore.load()
            guard let refreshToken = existing?.refreshToken else {
                throw KeycloakAuthError.missingRefreshToken
            }
            let refreshed = try await tokenService.refreshTokens(using: refreshToken)
            try tokenStore.save(refreshed)
            return refreshed
        }
        refreshTask = task
        lock.unlock()

        do {
            let refreshed = try await task.value
            setTokens(refreshed)
            lock.lock()
            refreshTask = nil
            lock.unlock()
            return refreshed
        } catch {
            lock.lock()
            refreshTask = nil
            lock.unlock()
            throw error
        }
    }

    public func endSessionURL() -> URL? {
        tokenService.endSessionURL(idTokenHint: currentTokens?.idToken)
    }

    public func accessTokenForRequest() async throws -> String? {
        guard hasSession else { return nil }
        return try await validAccessToken()
    }

    public func refreshAccessTokenForRequest() async throws -> String? {
        let tokens = try await refreshAccessToken()
        return tokens.accessToken
    }

    private func setTokens(_ tokens: AuthTokens?) {
        lock.lock()
        self.tokens = tokens
        lock.unlock()
    }
}

/// No-op session store retained for lightweight previews/tests.
public final class StubSessionStore: SessionStore, @unchecked Sendable {
    public private(set) var hasSession = false
    public private(set) var subject: String?
    public private(set) var currentTokens: AuthTokens?

    public init() {}
}
