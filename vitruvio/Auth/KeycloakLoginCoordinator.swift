//
//  KeycloakLoginCoordinator.swift
//  vitruvio
//

import AuthenticationServices
import Foundation
import UIKit
import VitruvioCore

@MainActor
final class KeycloakLoginCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let tokenService: KeycloakTokenService
    private var session: ASWebAuthenticationSession?

    init(tokenService: KeycloakTokenService = KeycloakTokenService()) {
        self.tokenService = tokenService
    }

    func login() async throws -> AuthTokens {
        let verifier = PKCE.makeCodeVerifier()
        let state = PKCE.makeState()
        let challenge = PKCE.codeChallenge(for: verifier)
        let authURL = try tokenService.makeAuthorizationURL(state: state, codeChallenge: challenge)

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AppConfig.oauthCallbackScheme
            ) { url, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: KeycloakAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let url else {
                    continuation.resume(throwing: KeycloakAuthError.invalidResponse)
                    return
                }
                continuation.resume(returning: url)
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.session = authSession
            if !authSession.start() {
                continuation.resume(throwing: KeycloakAuthError.invalidResponse)
            }
        }

        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        if items.contains(where: { $0.name == "error" }) {
            throw KeycloakAuthError.httpStatus(400)
        }
        guard let returnedState = items.first(where: { $0.name == "state" })?.value,
              returnedState == state,
              let code = items.first(where: { $0.name == "code" })?.value
        else {
            throw KeycloakAuthError.invalidResponse
        }

        return try await tokenService.exchangeAuthorizationCode(code, codeVerifier: verifier)
    }

    /// Ends the Keycloak SSO session via the OIDC end_session endpoint.
    /// Completes when Keycloak redirects back, or if the user cancels the sheet.
    func logout(endSessionURL: URL) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let authSession = ASWebAuthenticationSession(
                url: endSessionURL,
                callbackURLScheme: AppConfig.oauthCallbackScheme
            ) { _, _ in
                continuation.resume()
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.session = authSession
            if !authSession.start() {
                continuation.resume()
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return window
        }
        return scenes.flatMap(\.windows).first ?? ASPresentationAnchor()
    }
}
