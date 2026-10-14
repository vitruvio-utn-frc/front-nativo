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
                    NavigationLink {
                        ClientDetailView(admin: admin, client: row)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.user.displayName)
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
                }
            }
        }
        .navigationTitle("Clients")
        .refreshable { await admin.reloadDirectory() }
        .task { await admin.reloadDirectory() }
    }
}

struct ClientDetailView: View {
    @Bindable var admin: AdminWorkspaceModel
    let client: AdminDirectoryUser

    @State private var userMemberships: [UserMembershipDTO] = []
    @State private var catalog: [MembershipDTO] = []
    @State private var gymLinkedIds: Set<String> = []
    @State private var genders: [GenderDTO] = []
    @State private var showAssign = false
    @State private var error: String?
    @State private var status: String?
    @State private var isWorking = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private var membershipNameById: [String: MembershipDTO] {
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }

    private var genderName: String? {
        guard let genderId = client.user.genderId else { return nil }
        return genders.first { $0.id == String(genderId) }?.name
    }

    var body: some View {
        List {
            Section("Profile") {
                LabeledContent("Name", value: client.user.displayName)
                if let email = client.user.email {
                    LabeledContent("Email", value: email)
                }
                if let idNumber = client.user.idNumber {
                    LabeledContent("ID number", value: String(idNumber))
                }
                if let birthDate = client.user.birthDate {
                    LabeledContent("Birth date", value: dateFormatter.string(from: birthDate))
                }
                if let genderName {
                    LabeledContent("Gender", value: genderName)
                } else if let genderId = client.user.genderId {
                    LabeledContent("Gender", value: String(genderId))
                }
                if let height = client.user.height {
                    LabeledContent("Height", value: String(format: "%.0f cm", height))
                }
                if let weight = client.user.weight {
                    LabeledContent("Weight", value: String(format: "%.1f kg", weight))
                }
            }

            Section("Roles · \(admin.gymName)") {
                if client.rolesInGym.isEmpty {
                    Text("No roles in this gym").foregroundStyle(.secondary)
                } else {
                    ForEach(client.rolesInGym, id: \.self) { role in
                        Text(role.name)
                    }
                }
            }

            if let status {
                Section { Text(status).foregroundStyle(.secondary).font(.caption) }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }

            Section("Memberships") {
                if userMemberships.isEmpty {
                    ContentUnavailableView(
                        "No memberships",
                        systemImage: "creditcard",
                        description: Text("Tap + to assign a membership plan.")
                    )
                } else {
                    ForEach(userMemberships) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(membershipNameById[item.membershipId]?.name ?? item.membershipId)
                                Spacer()
                                Text(item.isActive ? "Active" : "Inactive")
                                    .font(.caption2.bold())
                                    .foregroundStyle(item.isActive ? .green : .secondary)
                            }
                            if let plan = membershipNameById[item.membershipId] {
                                Text(String(format: "$%.2f · %@", plan.price, plan.durationLabel))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(membershipDateRange(item))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Remove", role: .destructive) {
                                Task { await removeMembership(item.id) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(client.user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAssign = true
                } label: {
                    Label("Assign membership", systemImage: "plus")
                }
                .disabled(isWorking || assignableMemberships.isEmpty)
            }
        }
        .overlay { if isWorking { ProgressView() } }
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showAssign) {
            AssignMembershipSheet(
                memberName: client.user.displayName,
                memberships: assignableMemberships
            ) { membershipId, start, end in
                showAssign = false
                Task { await assignMembership(membershipId: membershipId, start: start, end: end) }
            } onCancel: {
                showAssign = false
            }
        }
    }

    private var assignableMemberships: [MembershipDTO] {
        let linked = catalog.filter { gymLinkedIds.contains($0.id) }
        return linked.isEmpty ? catalog : linked
    }

    private func membershipDateRange(_ item: UserMembershipDTO) -> String {
        let start = item.startDate.map { dateFormatter.string(from: $0) } ?? "—"
        let end = item.endDate.map { dateFormatter.string(from: $0) } ?? "—"
        return "\(start) → \(end)"
    }

    private func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let um = admin.service.listUserMemberships(forMemberId: client.user.id)
            async let m = admin.service.listMemberships()
            async let links = admin.service.listGymMembershipLinks()
            async let g = admin.service.listGenders()

            let (memberships, catalogItems, allLinks, genderItems) = try await (um, m, links, g)
            userMemberships = memberships
            catalog = catalogItems
            gymLinkedIds = Set(
                allLinks
                    .filter { $0.gymId.caseInsensitiveCompare(admin.gymId) == .orderedSame }
                    .map(\.membershipId)
            )
            genders = genderItems
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func assignMembership(membershipId: String, start: Date, end: Date) async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            _ = try await admin.service.createUserMembership(
                CreateUserMembershipRequest(
                    memberId: client.user.id,
                    membershipId: membershipId,
                    startDate: start,
                    endDate: end
                )
            )
            status = "Membership assigned"
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func removeMembership(_ id: String) async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            try await admin.service.deleteUserMembership(id: id)
            status = "Membership removed"
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct AssignMembershipSheet: View {
    let memberName: String
    let memberships: [MembershipDTO]
    var onAssign: (String, Date, Date) -> Void
    var onCancel: () -> Void

    @State private var membershipId: String
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    init(
        memberName: String,
        memberships: [MembershipDTO],
        onAssign: @escaping (String, Date, Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.memberName = memberName
        self.memberships = memberships
        self.onAssign = onAssign
        self.onCancel = onCancel
        _membershipId = State(initialValue: memberships.first?.id ?? "")
    }

    private var selected: MembershipDTO? {
        memberships.first { $0.id == membershipId }
    }

    private var canSave: Bool {
        !membershipId.isEmpty && end > start
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    Text(memberName)
                }
                Section("Plan") {
                    Picker("Membership", selection: $membershipId) {
                        ForEach(memberships) { plan in
                            Text("\(plan.name) · \(String(format: "$%.2f", plan.price))")
                                .tag(plan.id)
                        }
                    }
                    if let selected {
                        Text(selected.durationLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Dates") {
                    DatePicker("Start", selection: $start, displayedComponents: .date)
                    DatePicker("End", selection: $end, displayedComponents: .date)
                }
            }
            .navigationTitle("Assign membership")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        onAssign(membershipId, start, end)
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: membershipId) { _, newId in
                if let plan = memberships.first(where: { $0.id == newId }),
                   let days = plan.durationDays, days > 0 {
                    end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? end
                }
            }
            .onChange(of: start) { _, newStart in
                if let plan = selected, let days = plan.durationDays, days > 0 {
                    end = Calendar.current.date(byAdding: .day, value: days, to: newStart) ?? end
                }
            }
        }
    }
}
