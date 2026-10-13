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
    private(set) var hasSession = false
    private(set) var subject: String?
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
            }
        } catch {
            hasSession = false
            subject = nil
            lastError = error.localizedDescription
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
