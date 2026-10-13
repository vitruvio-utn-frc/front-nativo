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
    @State private var selectedRole: AppRole = .cliente
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

    private var freshManageTarget: AdminDirectoryUser? {
        guard let manageTarget else { return nil }
        return admin.directory.first { $0.id == manageTarget.id } ?? manageTarget
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
                    Text("No users match")
                        .foregroundStyle(.secondary)
                }
                ForEach(filtered) { row in
                    Button {
                        manageTarget = row
                        selectedRole = .cliente
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
        .overlay { if isWorking || admin.isLoading { ProgressView() } }
        .sheet(item: $manageTarget) { _ in
            if let target = freshManageTarget {
                manageRolesSheet(for: target)
            }
        }
        .modifier(RevokeRoleConfirmation(pending: $pendingRevoke, gymName: admin.gymName) { pending in
            await revoke(pending)
        })
        .task { await admin.reloadDirectory() }
    }

    @ViewBuilder
    private func manageRolesSheet(for target: AdminDirectoryUser) -> some View {
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
                        Task { await assign(to: target) }
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
                    Button("Done") { manageTarget = nil }
                }
            }
            .overlay { if isWorking { ProgressView() } }
            .modifier(RevokeRoleConfirmation(pending: $pendingRevoke, gymName: admin.gymName) { pending in
                await revoke(pending)
            })
        }
        .presentationDetents([.medium, .large])
    }

    private func assign(to target: AdminDirectoryUser) async {
        isWorking = true
        actionError = nil
        actionStatus = nil
        defer { isWorking = false }
        do {
            try await admin.service.assignRole(
                userId: target.user.id,
                gymId: admin.gymId,
                roleId: selectedRole.id
            )
            actionStatus = "Assigned \(selectedRole.name) to \(target.user.displayName)"
            await admin.reloadDirectory()
            if let updated = admin.directory.first(where: { $0.id == target.id }) {
                manageTarget = updated
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func revoke(_ pending: PendingRoleRevoke) async {
        isWorking = true
        actionError = nil
        actionStatus = nil
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
            if let id = manageTarget?.id,
               let updated = admin.directory.first(where: { $0.id == id }) {
                manageTarget = updated
            }
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

private struct RevokeRoleConfirmation: ViewModifier {
    @Binding var pending: PendingRoleRevoke?
    let gymName: String
    var onConfirm: (PendingRoleRevoke) async -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Revoke role?",
                isPresented: Binding(
                    get: { pending != nil },
                    set: { if !$0 { pending = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let pending {
                    Button("Revoke \(pending.role.name)", role: .destructive) {
                        Task { await onConfirm(pending) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    pending = nil
                }
            } message: {
                if let pending {
                    Text("Remove “\(pending.role.name)” from \(pending.user.user.displayName) in \(gymName).")
                }
            }
    }
}
