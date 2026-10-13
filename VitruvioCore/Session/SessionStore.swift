import Foundation

/// Auth/session seam. Concrete Keycloak + Keychain storage lands in `auth-keycloak`.
public protocol SessionStore: AnyObject, Sendable {
    var hasSession: Bool { get }
}

/// No-op session store for shell wiring until auth is implemented.
public final class StubSessionStore: SessionStore, @unchecked Sendable {
    public private(set) var hasSession = false

    public init() {}
}
