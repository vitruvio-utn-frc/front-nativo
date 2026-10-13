//
//  WatchSessionModel.swift
//  vitruvio.watch Watch App
//

import Foundation
import Observation
import VitruvioCore

@MainActor
@Observable
final class WatchSessionModel {
    enum CompanionPhase: Equatable {
        case signedOut
        /// Shared session present and active role is client-capable.
        case clientReady
        /// Session exists but active role is staff/admin (or missing client context).
        case clientContextRequired
    }

    private(set) var phase: CompanionPhase = .signedOut
    private(set) var hasSession = false
    private(set) var subject: String?
    private(set) var activeRoleName: String?
    private(set) var lastError: String?

    private let tokenStore: KeychainTokenStore
    private let sessionController: SessionController
    let apiClient: AuthenticatedAPIClient

    init() {
        let store = KeychainTokenStore()
        let controller = SessionController(tokenStore: store)
        self.tokenStore = store
        self.sessionController = controller
        self.apiClient = AuthenticatedAPIClient(tokenProvider: controller)
    }

    func reloadSharedSession() {
        lastError = nil
        do {
            if let tokens = try tokenStore.load() {
                try sessionController.applyLogin(tokens)
                hasSession = true
                subject = tokens.subject
            } else {
                hasSession = false
                subject = nil
                phase = .signedOut
                activeRoleName = nil
                return
            }
        } catch {
            hasSession = false
            subject = nil
            phase = .signedOut
            activeRoleName = nil
            lastError = error.localizedDescription
            return
        }

        let snapshot = SharedGymContextReader.load()
        activeRoleName = snapshot?.role?.name
        if snapshot?.isClientCapable == true {
            phase = .clientReady
        } else {
            // Staff/admin active on iPhone — Watch stays client-only (no ops UI).
            phase = .clientContextRequired
        }
    }

    /// Builds an authorized request using the shared session (for smoke verification).
    func authorizedRequest() async throws -> URLRequest {
        var request = URLRequest(url: AppConfig.apiBaseURL.appending(path: "health"))
        request.httpMethod = "GET"
        if let token = try await sessionController.accessTokenForRequest() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
