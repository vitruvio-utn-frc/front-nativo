//
//  AdminEnvironment.swift
//  vitruvio
//

import Foundation
import Observation
import VitruvioCore

@MainActor
@Observable
final class AdminWorkspaceModel {
    private(set) var directory: [AdminDirectoryUser] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    let gymId: String
    let gymName: String
    let companyId: String?
    let currentUserId: String
    let activeRole: AppRole?
    /// True if the user has a superadmin membership on any gym (not only the active one).
    let hasPlatformSuperadmin: Bool
    let service: AdminService

    init(
        gymId: String,
        gymName: String,
        companyId: String?,
        currentUserId: String,
        activeRole: AppRole?,
        hasPlatformSuperadmin: Bool,
        api: AuthenticatedAPIClient
    ) {
        self.gymId = gymId
        self.gymName = gymName
        self.companyId = companyId
        self.currentUserId = currentUserId
        self.activeRole = activeRole
        self.hasPlatformSuperadmin = hasPlatformSuperadmin
        self.service = AdminService(api: api)
    }

    /// Company CRUD / cross-company gyms: active superadmin, or superadmin on any gym.
    var canManageCompanies: Bool {
        activeRole?.canManageCompanies == true || hasPlatformSuperadmin
    }

    func reloadDirectory() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            directory = try await service.loadDirectory(gymId: gymId)
        } catch {
            lastError = error.localizedDescription
        }
    }

    var pendingUsers: [AdminDirectoryUser] {
        directory.filter(\.isPending)
    }

    var staffUsers: [AdminDirectoryUser] {
        service.staff(in: gymId, from: directory)
    }

    var clientUsers: [AdminDirectoryUser] {
        service.clients(in: gymId, from: directory)
    }
}
