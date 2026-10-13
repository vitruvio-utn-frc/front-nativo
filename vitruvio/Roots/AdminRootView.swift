//
//  AdminRootView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct AdminRootView: View {
    @Bindable var model: GymSessionModel
    @State private var admin: AdminWorkspaceModel?

    var body: some View {
        Group {
            if let admin {
                TabView {
                    NavigationStack {
                        RoleShellChrome(model: model, title: "Admin") {
                            AdminHubView(admin: admin, session: model)
                        }
                    }
                    .tabItem { Label("Home", systemImage: "house") }

                    NavigationStack {
                        RoleShellChrome(model: model, title: "Roles") {
                            AdminRolesView(admin: admin)
                        }
                    }
                    .tabItem { Label("Roles", systemImage: "person.badge.key") }

                    NavigationStack {
                        RoleShellChrome(model: model, title: "Staff") {
                            StaffDirectoryView(admin: admin)
                        }
                    }
                    .tabItem { Label("Staff", systemImage: "person.2") }

                    NavigationStack {
                        RoleShellChrome(model: model, title: "Clients") {
                            ClientDirectoryView(admin: admin)
                        }
                    }
                    .tabItem { Label("Clients", systemImage: "figure.run") }

                    NavigationStack {
                        RoleShellChrome(model: model, title: "Catalog") {
                            CatalogHubView(admin: admin, session: model)
                        }
                    }
                    .tabItem { Label("Catalog", systemImage: "list.bullet.rectangle") }
                }
            } else {
                ProgressView("Loading admin…")
            }
        }
        .task {
            guard let membership = model.gymContext.activeMembership else { return }
            let hasPlatformSuperadmin = model.gymContext.memberships.contains {
                $0.role == .superadmin
            }
            admin = AdminWorkspaceModel(
                gymId: membership.gymId,
                gymName: membership.gymName,
                companyId: membership.companyId,
                currentUserId: model.userId,
                activeRole: membership.role,
                hasPlatformSuperadmin: hasPlatformSuperadmin,
                api: model.session.apiClient
            )
        }
    }
}

private struct AdminHubView: View {
    @Bindable var admin: AdminWorkspaceModel
    @Bindable var session: GymSessionModel

    var body: some View {
        List {
            Section(admin.gymName) {
                Label("\(admin.pendingUsers.count) pending approvals", systemImage: "hourglass")
                Label("\(admin.staffUsers.count) staff", systemImage: "person.2")
                Label("\(admin.clientUsers.count) clients", systemImage: "figure.run")
            }
            Section("Quick links") {
                NavigationLink("Gyms") {
                    GymsAdminView(admin: admin) {
                        await session.load()
                    }
                }
                NavigationLink("Assign roles") { AdminRolesView(admin: admin) }
                NavigationLink("Memberships") { MembershipsAdminView(admin: admin) }
                NavigationLink("Machines") { MachinesAdminView(admin: admin) }
                NavigationLink("Appointments") { AppointmentsAdminView(admin: admin) }
            }
        }
        .task { await admin.reloadDirectory() }
        .refreshable { await admin.reloadDirectory() }
    }
}

private struct CatalogHubView: View {
    @Bindable var admin: AdminWorkspaceModel
    @Bindable var session: GymSessionModel

    var body: some View {
        List {
            NavigationLink("Gyms") {
                GymsAdminView(admin: admin) {
                    await session.load()
                }
            }
            NavigationLink("Memberships") { MembershipsAdminView(admin: admin) }
            NavigationLink("Machines") { MachinesAdminView(admin: admin) }
            NavigationLink("Appointments") { AppointmentsAdminView(admin: admin) }
        }
        .navigationTitle("Catalog")
    }
}
