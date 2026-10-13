//
//  MembershipsAdminView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct MembershipsAdminView: View {
    @Bindable var admin: AdminWorkspaceModel
    @State private var memberships: [MembershipDTO] = []
    @State private var links: [GymMembershipLinkDTO] = []
    @State private var name = ""
    @State private var price = ""
    @State private var days = "30"
    @State private var error: String?
    @State private var isWorking = false

    private var linkedIds: Set<String> {
        Set(
            links
                .filter { $0.gymId.caseInsensitiveCompare(admin.gymId) == .orderedSame }
                .map(\.membershipId)
        )
    }

    var body: some View {
        List {
            Section("Create membership") {
                TextField("Name", text: $name)
                TextField("Price", text: $price).keyboardType(.decimalPad)
                TextField("Duration (days)", text: $days).keyboardType(.numberPad)
                Button("Create") { Task { await create() } }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
            }

            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }

            Section("Catalog") {
                if memberships.isEmpty {
                    Text("No memberships yet").foregroundStyle(.secondary)
                }
                ForEach(memberships) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(String(format: "$%.2f", item.price))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if linkedIds.contains(item.id) {
                            Button("Unlink") {
                                Task { await unlink(item.id) }
                            }
                            .font(.caption)
                        } else {
                            Button("Link to gym") {
                                Task { await link(item.id) }
                            }
                            .font(.caption)
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            Task { await delete(item.id) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Memberships")
        .overlay { if isWorking { ProgressView() } }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let m = admin.service.listMemberships()
            async let l = admin.service.listGymMembershipLinks()
            (memberships, links) = try await (m, l)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func create() async {
        guard let priceValue = Double(price.replacingOccurrences(of: ",", with: ".")),
              let dayValue = Int(days) else {
            error = "Price and days must be numbers"
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let created = try await admin.service.createMembership(
                CreateMembershipRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    price: priceValue,
                    durationDays: dayValue
                )
            )
            try await admin.service.linkMembership(gymId: admin.gymId, membershipId: created.id)
            name = ""
            price = ""
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func link(_ id: String) async {
        do {
            try await admin.service.linkMembership(gymId: admin.gymId, membershipId: id)
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func unlink(_ id: String) async {
        do {
            try await admin.service.unlinkMembership(gymId: admin.gymId, membershipId: id)
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ id: String) async {
        do {
            if linkedIds.contains(id) {
                try await admin.service.unlinkMembership(gymId: admin.gymId, membershipId: id)
            }
            try await admin.service.deleteMembership(id: id)
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
