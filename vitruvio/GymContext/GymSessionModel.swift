//
//  GymSessionModel.swift
//  vitruvio
//

import Foundation
import Observation
import VitruvioCore

@MainActor
@Observable
final class GymSessionModel {
    enum Phase: Equatable {
        case loading
        case pickMembership
        case active
        case unsupportedRole
        case failed
    }

    private(set) var phase: Phase = .loading
    private(set) var lastError: String?
    private(set) var isBusy = false

    let userId: String
    let gymContext: GymContextController
    let session: AuthSessionModel

    init(userId: String, session: AuthSessionModel, gymContext: GymContextController? = nil) {
        self.userId = userId
        self.session = session
        self.gymContext = gymContext ?? GymContextController(api: session.apiClient)
    }

    func load() async {
        isBusy = true
        lastError = nil
        phase = .loading
        defer { isBusy = false }

        do {
            try await gymContext.load(userId: userId)
            reconcilePhase()
            pushCompanionGymContext()
        } catch {
            lastError = error.localizedDescription
            phase = .failed
        }
    }

    func select(_ membership: GymMembership) {
        gymContext.select(membership)
        reconcilePhase()
        pushCompanionGymContext()
    }

    func selectShell(_ shell: RoleShell) {
        gymContext.selectShell(shell)
        reconcilePhase()
        pushCompanionGymContext()
    }

    func showPicker() {
        gymContext.clearActiveSelection()
        reconcilePhase()
        pushCompanionGymContext()
    }

    func clearAndSignOut() async {
        gymContext.clear()
        pushCompanionGymContext()
        await session.logout()
    }

    private func reconcilePhase() {
        if gymContext.memberships.isEmpty {
            // Onboarding should have kept us in pending; treat as failed handoff.
            lastError = "No hay roles de gimnasio disponibles"
            phase = .failed
            return
        }

        guard let active = gymContext.activeMembership else {
            phase = .pickMembership
            return
        }

        if active.role == nil {
            phase = .unsupportedRole
            return
        }

        phase = .active
    }

    private func pushCompanionGymContext() {
        Task { await CompanionPhoneGateway.shared.publish() }
    }
}
