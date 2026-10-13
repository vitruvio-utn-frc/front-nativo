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
    private let session: AuthSessionModel

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
        } catch {
            lastError = error.localizedDescription
            phase = .failed
        }
    }

    func select(_ membership: GymMembership) {
        gymContext.select(membership)
        reconcilePhase()
    }

    func selectShell(_ shell: RoleShell) {
        gymContext.selectShell(shell)
        reconcilePhase()
    }

    func showPicker() {
        gymContext.clearActiveSelection()
        reconcilePhase()
    }

    func clearAndSignOut() async {
        gymContext.clear()
        await session.logout()
    }

    private func reconcilePhase() {
        if gymContext.memberships.isEmpty {
            // Onboarding should have kept us in pending; treat as failed handoff.
            lastError = "No gym roles available"
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
}
