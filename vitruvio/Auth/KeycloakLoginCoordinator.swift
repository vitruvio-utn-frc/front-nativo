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
            // ASWebAuthenticationSession may invoke the completion handler before
            // `start()` returns; guard against double-resume.
            let once = CheckedThrowingResumeOnce<URL>(continuation)
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AppConfig.oauthCallbackScheme
            ) { [weak self] url, error in
                self?.session = nil
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        once.resume(throwing: KeycloakAuthError.cancelled)
                    } else {
                        once.resume(throwing: error)
                    }
                    return
                }
                guard let url else {
                    once.resume(throwing: KeycloakAuthError.invalidResponse)
                    return
                }
                once.resume(returning: url)
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.session = authSession
            if !authSession.start() {
                once.resume(throwing: KeycloakAuthError.invalidResponse)
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
            let once = CheckedResumeOnce(continuation)
            let authSession = ASWebAuthenticationSession(
                url: endSessionURL,
                callbackURLScheme: AppConfig.oauthCallbackScheme
            ) { [weak self] _, _ in
                self?.session = nil
                once.resume()
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.session = authSession
            if !authSession.start() {
                once.resume()
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

/// Ensures a `CheckedContinuation` is resumed at most once.
@MainActor
private final class CheckedResumeOnce {
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

/// Ensures a throwing `CheckedContinuation` is resumed at most once.
@MainActor
private final class CheckedThrowingResumeOnce<T> {
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        continuation?.resume(returning: value)
        continuation = nil
    }

    func resume(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
