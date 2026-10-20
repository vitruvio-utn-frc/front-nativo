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
                    .tabItem { Label("Inicio", systemImage: "house") }

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
                        RoleShellChrome(model: model, title: "Clientes") {
                            ClientDirectoryView(admin: admin)
                        }
                    }
                    .tabItem { Label("Clientes", systemImage: "figure.run") }

                    NavigationStack {
                        RoleShellChrome(model: model, title: "Catálogo") {
                            CatalogHubView(admin: admin, session: model)
                        }
                    }
                    .tabItem { Label("Catálogo", systemImage: "list.bullet.rectangle") }
                }
            } else {
                ProgressView("Cargando administración…")
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
                Label("\(admin.pendingUsers.count) aprobaciones pendientes", systemImage: "hourglass")
                Label("\(admin.staffUsers.count) staff", systemImage: "person.2")
                Label("\(admin.clientUsers.count) clientes", systemImage: "figure.run")
            }
            Section("Accesos rápidos") {
                NavigationLink("Gimnasios") {
                    GymsAdminView(admin: admin) {
                        await session.load()
                    }
                }
                NavigationLink("Asignar roles") { AdminRolesView(admin: admin) }
                NavigationLink("Membresías") { MembershipsAdminView(admin: admin) }
                NavigationLink("Máquinas") { MachinesAdminView(admin: admin) }
                NavigationLink("Turnos") { AppointmentsAdminView(admin: admin) }
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
            NavigationLink("Gimnasios") {
                GymsAdminView(admin: admin) {
                    await session.load()
                }
            }
            NavigationLink("Membresías") { MembershipsAdminView(admin: admin) }
            NavigationLink("Máquinas") { MachinesAdminView(admin: admin) }
            NavigationLink("Turnos") { AppointmentsAdminView(admin: admin) }
        }
        .navigationTitle("Catálogo")
    }
}
