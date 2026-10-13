//
//  AdminRolesView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct AdminRolesView: View {
    @Bindable var admin: AdminWorkspaceModel
    @State private var query = ""
    @State private var showPendingOnly = true
    @State private var assignTarget: AdminDirectoryUser?
    @State private var selectedRole: AppRole = .cliente
    @State private var actionError: String?
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

            if let actionError {
                Section {
                    Text(actionError).foregroundStyle(.red).font(.caption)
                }
            }

            Section(showPendingOnly ? "Pending users" : "Users") {
                if filtered.isEmpty {
                    Text("No users match")
                        .foregroundStyle(.secondary)
                }
                ForEach(filtered) { row in
                    Button {
                        assignTarget = row
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
                            if !row.rolesInGym.isEmpty {
                                Text(row.rolesInGym.map(\.name).joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        ForEach(row.rolesInGym, id: \.self) { role in
                            Button("Revoke \(role.name)", role: .destructive) {
                                Task { await revoke(userId: row.user.id, role: role) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Roles")
        .refreshable { await admin.reloadDirectory() }
        .overlay { if isWorking || admin.isLoading { ProgressView() } }
        .sheet(item: $assignTarget) { target in
            NavigationStack {
                Form {
                    Section("User") {
                        Text(target.user.displayName)
                        if let email = target.user.email { Text(email).foregroundStyle(.secondary) }
                    }
                    Section("Role in \(admin.gymName)") {
                        Picker("Role", selection: $selectedRole) {
                            ForEach(AppRole.allCases) { role in
                                Text(role.name).tag(role)
                            }
                        }
                    }
                }
                .navigationTitle("Assign role")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { assignTarget = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Assign") {
                            Task { await assign(to: target) }
                        }
                        .disabled(isWorking)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task { await admin.reloadDirectory() }
    }

    private func assign(to target: AdminDirectoryUser) async {
        isWorking = true
        actionError = nil
        defer { isWorking = false }
        do {
            try await admin.service.assignRole(
                userId: target.user.id,
                gymId: admin.gymId,
                roleId: selectedRole.id
            )
            assignTarget = nil
            await admin.reloadDirectory()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func revoke(userId: String, role: AppRole) async {
        isWorking = true
        actionError = nil
        defer { isWorking = false }
        do {
            try await admin.service.revokeRole(userId: userId, gymId: admin.gymId, roleId: role.id)
            await admin.reloadDirectory()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
