//
//  AdminDirectoryViews.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct StaffDirectoryView: View {
    @Bindable var admin: AdminWorkspaceModel

    var body: some View {
        directoryList(title: "Staff", rows: admin.staffUsers, empty: "No staff in this gym yet")
    }

    @ViewBuilder
    private func directoryList(title: String, rows: [AdminDirectoryUser], empty: String) -> some View {
        List {
            if rows.isEmpty {
                ContentUnavailableView(empty, systemImage: "person.2")
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.user.displayName)
                        if let email = row.user.email {
                            Text(email).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(row.rolesInGym.map(\.name).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle(title)
        .refreshable { await admin.reloadDirectory() }
        .task { await admin.reloadDirectory() }
    }
}

struct ClientDirectoryView: View {
    @Bindable var admin: AdminWorkspaceModel

    var body: some View {
        List {
            if admin.clientUsers.isEmpty {
                ContentUnavailableView("No clients in this gym yet", systemImage: "figure.run")
            } else {
                ForEach(admin.clientUsers) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.user.displayName)
                        if let email = row.user.email {
                            Text(email).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Clients")
        .refreshable { await admin.reloadDirectory() }
        .task { await admin.reloadDirectory() }
    }
}
