import Foundation

/// Central configuration for API and Keycloak OIDC.
/// Views MUST read these values from Core instead of hardcoding auth endpoints.
/// Companion sync uses Watch Connectivity (not App Group).
public enum AppConfig {
    /// Legacy identifier retained for reference only — not used for companion sync.
    public static let appGroupIdentifier = "group.com.santiago-alvarado.vitruvio"

    /// Legacy Keychain access-group suffix — companion auth uses local Keychain + WCSession.
    public static let keychainAccessGroupSuffix = "com.santiago-alvarado.vitruvio"

    public static let apiBaseURL = URL(string: "https://vitruvio.santiago-alvarado.com")!

    public static let keycloakIssuerURL = URL(string: "https://keycloak-local.santiago-alvarado.com/realms/vitruvio")!
    public static let keycloakClientID = "vitruvio-ios"
    public static let keycloakRedirectURI = URL(string: "com.santiago-alvarado.vitruvio://oauth2redirect")!
    public static let keycloakScopes = ["openid", "profile", "email", "offline_access"]

    public static var keycloakAuthorizationEndpoint: URL {
        keycloakIssuerURL.appending(path: "protocol/openid-connect/auth")
    }

    public static var keycloakTokenEndpoint: URL {
        keycloakIssuerURL.appending(path: "protocol/openid-connect/token")
    }

    public static var keycloakEndSessionEndpoint: URL {
        keycloakIssuerURL.appending(path: "protocol/openid-connect/logout")
    }

    public static var oauthCallbackScheme: String {
        keycloakRedirectURI.scheme ?? "com.santiago-alvarado.vitruvio"
    }
}
