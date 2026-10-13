import Foundation

/// Central configuration for API and shared-container identity.
/// Values are placeholders until auth and environment wiring land.
public enum AppConfig {
    public static let appGroupIdentifier = "group.com.santiago-alvarado.vitruvio"
    public static let apiBaseURL = URL(string: "https://api.vitruvio.local")!
    public static let keycloakIssuerURL = URL(string: "https://auth.vitruvio.local/realms/vitruvio")!
    public static let keycloakClientID = "vitruvio-ios"
}
