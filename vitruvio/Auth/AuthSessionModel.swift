//
//  AuthSessionModel.swift
//  vitruvio
//

import Foundation
import Observation
import VitruvioCore

@MainActor
@Observable
final class AuthSessionModel {
    private(set) var state: AuthSessionState = .unauthenticated
    private(set) var isBusy = false
    private(set) var lastError: String?

    let sessionController: SessionController
    let apiClient: AuthenticatedAPIClient
    private let loginCoordinator: KeycloakLoginCoordinator

    init(sessionController: SessionController = SessionController()) {
        self.sessionController = sessionController
        self.apiClient = AuthenticatedAPIClient(tokenProvider: sessionController)
        self.loginCoordinator = KeycloakLoginCoordinator()
    }

    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }

    var subject: String? {
        if case .authenticated(let tokens) = state {
            return tokens.subject
        }
        return nil
    }

    func restoreOnLaunch() async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            state = try await sessionController.restoreSession()
        } catch {
            state = .unauthenticated
            lastError = error.localizedDescription
        }
        pushCompanionAuth()
    }

    func login() async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            let tokens = try await loginCoordinator.login()
            try sessionController.applyLogin(tokens)
            state = .authenticated(tokens)
            pushCompanionAuth()
        } catch let error as KeycloakAuthError where error == .cancelled {
            // Stay unauthenticated; do not store tokens.
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func logout() async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        // Capture end-session URL (needs id_token) before clearing local Keychain.
        let endSessionURL = sessionController.endSessionURL()

        if let endSessionURL {
            await loginCoordinator.logout(endSessionURL: endSessionURL)
        }

        do {
            try sessionController.logout()
            state = .unauthenticated
        } catch {
            // Local clear failed, but Keycloak end_session may already have run.
            state = .unauthenticated
            lastError = error.localizedDescription
        }
        pushCompanionAuth()
    }

    private func pushCompanionAuth() {
        Task { await CompanionPhoneGateway.shared.publish() }
    }
}
