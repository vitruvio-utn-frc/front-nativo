//
//  AdminRolesView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct AdminRolesView: View {
    @Bindable var admin: AdminWorkspaceModel
    @State private var query = ""
    @State private var showPendingOnly = false
    @State private var manageTarget: AdminDirectoryUser?
    @State private var pendingRevoke: PendingRoleRevoke?
    @State private var actionError: String?
    @State private var actionStatus: String?
    @State private var isWorking = false

    private var filtered: [AdminDirectoryUser] {
        admin.directory.filter { row in
            if showPendingOnly && !row.isPending { return false }
            if query.isEmpty { return true }
            let q = query.lowercased()
            return row.user.displayName.lowercased().contains(q)
                || (row.user.email?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        List {
            Section {
                Toggle("Pending only", isOn: $showPendingOnly)
                TextField("Search name or email", text: $query)
                    .textInputAutocapitalization(.never)
            }

            if let actionStatus {
                Section { Text(actionStatus).foregroundStyle(.secondary).font(.caption) }
            }
            if let actionError {
                Section { Text(actionError).foregroundStyle(.red).font(.caption) }
            }

            Section(showPendingOnly ? "Pending users" : "Users") {
                if filtered.isEmpty {
                    Text(admin.isLoading ? "Loading users…" : "No users match")
                        .foregroundStyle(.secondary)
                }
                ForEach(filtered) { row in
                    Button {
                        manageTarget = row
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.user.displayName)
                                if row.isPending {
                                    Text("PENDING")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.orange.opacity(0.2))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                            if let email = row.user.email {
                                Text(email).font(.caption).foregroundStyle(.secondary)
                            }
                            if row.rolesInGym.isEmpty {
                                Text("No roles in this gym")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text(row.rolesInGym.map(\.name).joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        ForEach(row.rolesInGym, id: \.self) { role in
                            Button("Revoke \(role.name)", role: .destructive) {
                                pendingRevoke = PendingRoleRevoke(user: row, role: role)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Roles")
        .refreshable { await admin.reloadDirectory() }
        .toolbar {
            if isWorking || admin.isLoading {
                ToolbarItem(placement: .status) {
                    ProgressView()
                }
            }
        }
        .sheet(item: $manageTarget) { target in
            ManageRolesSheet(
                admin: admin,
                userId: target.id,
                initialUser: target
            ) {
                manageTarget = nil
            } onAssigned: { roleName, displayName in
                actionStatus = "Assigned \(roleName) to \(displayName)"
                actionError = nil
            } onRevoked: { roleName, displayName in
                actionStatus = "Revoked \(roleName) from \(displayName)"
                actionError = nil
            }
        }
        .confirmationDialog(
            "Revoke role?",
            isPresented: Binding(
                get: { pendingRevoke != nil && manageTarget == nil },
                set: { if !$0 { pendingRevoke = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pending = pendingRevoke {
                Button("Revoke \(pending.role.name)", role: .destructive) {
                    Task { await revokeFromList(pending) }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingRevoke = nil
            }
        } message: {
            if let pending = pendingRevoke {
                Text("Remove “\(pending.role.name)” from \(pending.user.user.displayName) in \(admin.gymName).")
            }
        }
        .task { await admin.reloadDirectory() }
    }

    private func revokeFromList(_ pending: PendingRoleRevoke) async {
        isWorking = true
        actionError = nil
        defer {
            isWorking = false
            pendingRevoke = nil
        }
        do {
            try await admin.service.revokeRole(
                userId: pending.user.user.id,
                gymId: admin.gymId,
                roleId: pending.role.id
            )
            actionStatus = "Revoked \(pending.role.name) from \(pending.user.user.displayName)"
            await admin.reloadDirectory()
        } catch {
            actionError = error.localizedDescription
        }
    }
}

private struct ManageRolesSheet: View {
    @Bindable var admin: AdminWorkspaceModel
    let userId: String
    let initialUser: AdminDirectoryUser
    var onDone: () -> Void
    var onAssigned: (String, String) -> Void
    var onRevoked: (String, String) -> Void

    @State private var selectedRole: AppRole = .cliente
    @State private var pendingRevoke: PendingRoleRevoke?
    @State private var actionError: String?
    @State private var isWorking = false

    private var target: AdminDirectoryUser {
        admin.directory.first { $0.id == userId } ?? initialUser
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("User") {
                    Text(target.user.displayName)
                    if let email = target.user.email {
                        Text(email).foregroundStyle(.secondary)
                    }
                }

                Section("Roles in \(admin.gymName)") {
                    if target.rolesInGym.isEmpty {
                        Text("No roles assigned")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(target.rolesInGym, id: \.self) { role in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(role.name)
                                    Text(role.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Revoke", role: .destructive) {
                                    pendingRevoke = PendingRoleRevoke(user: target, role: role)
                                }
                                .disabled(isWorking)
                            }
                        }
                    }
                }

                Section("Assign role") {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(AppRole.allCases) { role in
                            Text(role.name).tag(role)
                        }
                    }
                    Button("Assign \(selectedRole.name)") {
                        Task { await assign() }
                    }
                    .disabled(isWorking || target.rolesInGym.contains(selectedRole))
                }

                if let actionError {
                    Section {
                        Text(actionError).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Manage roles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDone)
                }
                if isWorking {
                    ToolbarItem(placement: .status) {
                        ProgressView()
                    }
                }
            }
            .confirmationDialog(
                "Revoke role?",
                isPresented: Binding(
                    get: { pendingRevoke != nil },
                    set: { if !$0 { pendingRevoke = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let pending = pendingRevoke {
                    Button("Revoke \(pending.role.name)", role: .destructive) {
                        Task { await revoke(pending) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingRevoke = nil
                }
            } message: {
                if let pending = pendingRevoke {
                    Text("Remove “\(pending.role.name)” from \(pending.user.user.displayName) in \(admin.gymName).")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isWorking)
    }

    private func assign() async {
        isWorking = true
        actionError = nil
        defer { isWorking = false }
        do {
            try await admin.service.assignRole(
                userId: target.user.id,
                gymId: admin.gymId,
                roleId: selectedRole.id
            )
            onAssigned(selectedRole.name, target.user.displayName)
            await admin.reloadDirectory()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func revoke(_ pending: PendingRoleRevoke) async {
        isWorking = true
        actionError = nil
        defer {
            isWorking = false
            pendingRevoke = nil
        }
        do {
            try await admin.service.revokeRole(
                userId: pending.user.user.id,
                gymId: admin.gymId,
                roleId: pending.role.id
            )
            onRevoked(pending.role.name, pending.user.user.displayName)
            await admin.reloadDirectory()
        } catch {
            actionError = error.localizedDescription
        }
    }
}

private struct PendingRoleRevoke: Identifiable {
    let user: AdminDirectoryUser
    let role: AppRole

    var id: String { "\(user.id)|\(role.id)" }
}
