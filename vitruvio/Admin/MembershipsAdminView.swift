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
    @State private var showCreate = false
    @State private var error: String?
    @State private var status: String?
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
            if let status {
                Section { Text(status).foregroundStyle(.secondary).font(.caption) }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }

            Section("Catálogo · \(admin.gymName)") {
                if memberships.isEmpty {
                    ContentUnavailableView(
                        "Todavía no hay membresías",
                        systemImage: "creditcard",
                        description: Text("Tocá + para crear una membresía.")
                    )
                }
                ForEach(memberships) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                            Text(membershipSubtitle(item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if linkedIds.contains(item.id) {
                            Button("Desvincular") {
                                Task { await unlink(item.id) }
                            }
                            .font(.caption)
                        } else {
                            Button("Vincular al gimnasio") {
                                Task { await link(item.id) }
                            }
                            .font(.caption)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Eliminar", role: .destructive) {
                            Task { await delete(item.id) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Membresías")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Label("Agregar membresía", systemImage: "plus")
                }
                .disabled(isWorking)
            }
        }
        .overlay { if isWorking { ProgressView() } }
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showCreate) {
            CreateMembershipSheet(
                service: admin.service,
                gymId: admin.gymId,
                gymName: admin.gymName
            ) { created in
                status = "“\(created.name)” creada y vinculada a \(admin.gymName)."
                showCreate = false
                Task { await reload() }
            } onCancel: {
                showCreate = false
            }
        }
    }

    private func membershipSubtitle(_ item: MembershipDTO) -> String {
        let price = String(format: "$%.2f", item.price)
        let label = item.durationLabel
        return label.isEmpty ? price : "\(price) · \(label)"
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

    private func link(_ id: String) async {
        do {
            try await admin.service.linkMembership(gymId: admin.gymId, membershipId: id)
            status = "Vinculada al gimnasio"
            error = nil
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func unlink(_ id: String) async {
        do {
            try await admin.service.unlinkMembership(gymId: admin.gymId, membershipId: id)
            status = "Desvinculada del gimnasio"
            error = nil
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
            status = "Membresía eliminada"
            error = nil
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct CreateMembershipSheet: View {
    let service: AdminService
    let gymId: String
    let gymName: String
    var onCreated: (MembershipDTO) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var price = ""
    @State private var days = "30"
    @State private var linkToGym = true
    @State private var error: String?
    @State private var isWorking = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Double(price.replacingOccurrences(of: ",", with: ".")) != nil
            && Int(days) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Membresía") {
                    TextField("Nombre", text: $name)
                    TextField("Precio", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("Duración (días)", text: $days)
                        .keyboardType(.numberPad)
                }
                Section {
                    Toggle("Vincular a \(gymName)", isOn: $linkToGym)
                    Text("Gimnasio activo de esta sesión de admin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Nueva membresía")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") { Task { await create() } }
                        .disabled(!canSave || isWorking)
                }
            }
            .overlay { if isWorking { ProgressView() } }
        }
    }

    private func create() async {
        guard let priceValue = Double(price.replacingOccurrences(of: ",", with: ".")),
              let dayValue = Int(days) else {
            error = "El precio y los días deben ser números"
            return
        }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            let created = try await service.createMembership(
                CreateMembershipRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    price: priceValue,
                    durationDays: dayValue
                )
            )
            if linkToGym {
                try await service.linkMembership(gymId: gymId, membershipId: created.id)
            }
            onCreated(created)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
