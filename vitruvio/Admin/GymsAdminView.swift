//
//  GymsAdminView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct GymsAdminView: View {
    @Bindable var admin: AdminWorkspaceModel
    var onGymCreated: (() async -> Void)?

    @State private var gyms: [GymDTO] = []
    @State private var companies: [CompanyDTO] = []
    @State private var companyId = ""

    @State private var error: String?
    @State private var status: String?
    @State private var isWorking = false
    @State private var showCreateGym = false
    @State private var showCreateCompany = false
    @State private var editingGym: GymDTO?
    @State private var gymPendingDelete: GymDTO?

    private var canManageCompanies: Bool { admin.canManageCompanies }

    private var gymsForScope: [GymDTO] {
        guard !companyId.isEmpty else { return [] }
        return gyms.filter { ($0.companyId ?? "").caseInsensitiveCompare(companyId) == .orderedSame }
    }

    private var selectedCompanyName: String {
        companies.first { $0.id.caseInsensitiveCompare(companyId) == .orderedSame }?.name
            ?? "company"
    }

    private var hasCompanyScope: Bool {
        !companyId.isEmpty
    }

    var body: some View {
        List {
            if canManageCompanies {
                superadminCompanySection
            } else {
                adminCompanySection
            }

            if let status {
                Section { Text(status).foregroundStyle(.secondary).font(.caption) }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }

            if hasCompanyScope {
                gymListSection
            } else if canManageCompanies {
                Section {
                    Text("Select a company or tap + → Add company.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Text("This admin account has no company on the active gym.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Gyms")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if canManageCompanies {
                    Menu {
                        Button {
                            showCreateCompany = true
                        } label: {
                            Label("Add company", systemImage: "building.2")
                        }
                        Button {
                            showCreateGym = true
                        } label: {
                            Label("Add gym", systemImage: "dumbbell")
                        }
                        .disabled(!hasCompanyScope)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(isWorking)
                } else {
                    Button {
                        showCreateGym = true
                    } label: {
                        Label("Add gym", systemImage: "plus")
                    }
                    .disabled(!hasCompanyScope || isWorking)
                }
            }
        }
        .overlay { if isWorking { ProgressView() } }
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showCreateCompany) {
            CreateCompanySheet(service: admin.service) { created in
                status = "Company “\(created.name)” created. Tap + to add a gym."
                showCreateCompany = false
                companyId = created.id
                Task { await reload() }
            } onCancel: {
                showCreateCompany = false
            }
        }
        .sheet(isPresented: $showCreateGym) {
            CreateGymSheet(
                companies: companies,
                canChangeCompany: canManageCompanies,
                initialCompanyId: companyId,
                adminUserId: admin.currentUserId,
                service: admin.service
            ) { created in
                status = "Created “\(created.name)”. Switch gym/role if needed to open it."
                showCreateGym = false
                companyId = created.companyId ?? companyId
                Task {
                    await reload()
                    await onGymCreated?()
                }
            } onCancel: {
                showCreateGym = false
            }
        }
        .sheet(item: $editingGym) { gym in
            EditGymSheet(
                gym: gym,
                companies: companies,
                canChangeCompany: canManageCompanies,
                lockedCompanyId: canManageCompanies ? nil : companyId,
                service: admin.service
            ) { updated in
                status = "Updated “\(updated.name)”"
                editingGym = nil
                Task {
                    await reload()
                    await onGymCreated?()
                }
            } onCancel: {
                editingGym = nil
            }
        }
        .confirmationDialog(
            "Delete gym?",
            isPresented: Binding(
                get: { gymPendingDelete != nil },
                set: { if !$0 { gymPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete “\(gymPendingDelete?.name ?? "gym")”", role: .destructive) {
                if let gym = gymPendingDelete {
                    Task { await deleteGym(gym) }
                }
            }
            Button("Cancel", role: .cancel) {
                gymPendingDelete = nil
            }
        } message: {
            Text("This removes the gym from the API. Related roles/links may fail if the backend still references it.")
        }
    }

    @ViewBuilder
    private var superadminCompanySection: some View {
        Section("Company") {
            if companies.isEmpty {
                ContentUnavailableView(
                    "No companies yet",
                    systemImage: "building.2",
                    description: Text("Tap + → Add company.")
                )
            } else {
                Picker("Company", selection: $companyId) {
                    Text("Select").tag("")
                    ForEach(companies) { company in
                        Text(company.name).tag(company.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var adminCompanySection: some View {
        Section("Company") {
            Text(selectedCompanyName)
            Text("Gym admins can only manage gyms in this company.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var gymListSection: some View {
        Section("Gyms · \(selectedCompanyName)") {
            if gymsForScope.isEmpty {
                ContentUnavailableView(
                    "No gyms yet",
                    systemImage: "building.2",
                    description: Text("Tap + to create a gym for this company.")
                )
            }
            ForEach(gymsForScope) { gym in
                Button {
                    editingGym = gym
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gym.name)
                            if !gym.locationLine.isEmpty {
                                Text(gym.locationLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let address = gym.address, !address.isEmpty {
                                Text(address)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        gymPendingDelete = gym
                    }
                }
            }
        }
    }

    private func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let g = admin.service.listGyms()
            async let c = admin.service.listCompanies()
            let (allGyms, allCompanies) = try await (g, c)

            if canManageCompanies {
                gyms = allGyms
                companies = allCompanies
                if companyId.isEmpty {
                    companyId = admin.companyId ?? allCompanies.first?.id ?? ""
                }
                if !companyId.isEmpty, !companies.contains(where: { $0.id == companyId }) {
                    companyId = companies.first?.id ?? ""
                }
            } else {
                guard let scopedCompanyId = admin.companyId, !scopedCompanyId.isEmpty else {
                    gyms = []
                    companies = []
                    companyId = ""
                    error = "Active gym has no company; cannot manage gyms."
                    return
                }
                companyId = scopedCompanyId
                companies = allCompanies.filter {
                    $0.id.caseInsensitiveCompare(scopedCompanyId) == .orderedSame
                }
                gyms = allGyms.filter {
                    ($0.companyId ?? "").caseInsensitiveCompare(scopedCompanyId) == .orderedSame
                }
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteGym(_ gym: GymDTO) async {
        isWorking = true
        status = nil
        error = nil
        defer {
            isWorking = false
            gymPendingDelete = nil
        }
        do {
            if !canManageCompanies, let scoped = admin.companyId,
               (gym.companyId ?? "").caseInsensitiveCompare(scoped) != .orderedSame {
                error = "Gym admins can only delete gyms in their company."
                return
            }
            try await admin.service.deleteGym(id: gym.id)
            status = "Deleted “\(gym.name)”"
            await reload()
            await onGymCreated?()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct CreateCompanySheet: View {
    let service: AdminService
    var onCreated: (CompanyDTO) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var error: String?
    @State private var isWorking = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Company") {
                    TextField("Name", text: $name)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("New company")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(!canSave || isWorking)
                }
            }
            .overlay { if isWorking { ProgressView() } }
        }
    }

    private func create() async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            let created = try await service.createCompany(
                CreateCompanyRequest(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            onCreated(created)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct CreateGymSheet: View {
    let companies: [CompanyDTO]
    let canChangeCompany: Bool
    let initialCompanyId: String
    let adminUserId: String
    let service: AdminService
    var onCreated: (GymDTO) -> Void
    var onCancel: () -> Void

    @State private var companyId: String
    @State private var name = ""
    @State private var address = ""
    @State private var zipCode = ""
    @State private var city = ""
    @State private var state = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var error: String?
    @State private var isWorking = false

    init(
        companies: [CompanyDTO],
        canChangeCompany: Bool,
        initialCompanyId: String,
        adminUserId: String,
        service: AdminService,
        onCreated: @escaping (GymDTO) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.companies = companies
        self.canChangeCompany = canChangeCompany
        self.initialCompanyId = initialCompanyId
        self.adminUserId = adminUserId
        self.service = service
        self.onCreated = onCreated
        self.onCancel = onCancel
        _companyId = State(initialValue: initialCompanyId)
    }

    private var canSave: Bool {
        !companyId.isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !address.trimmingCharacters(in: .whitespaces).isEmpty
            && !zipCode.trimmingCharacters(in: .whitespaces).isEmpty
            && !city.trimmingCharacters(in: .whitespaces).isEmpty
            && !state.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Company") {
                    if canChangeCompany {
                        Picker("Company", selection: $companyId) {
                            ForEach(companies) { company in
                                Text(company.name).tag(company.id)
                            }
                        }
                    } else {
                        Text(companies.first { $0.id == companyId }?.name ?? companyId)
                        Text("Company is fixed for gym admins.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Gym") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Zip code", text: $zipCode)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("New gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(!canSave || isWorking)
                }
            }
            .overlay { if isWorking { ProgressView() } }
        }
    }

    private func create() async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            let gym = try await service.createGymAndAssignAdmin(
                CreateGymRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    companyId: companyId,
                    address: address.trimmingCharacters(in: .whitespacesAndNewlines),
                    zipCode: zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
                    city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                    state: state.trimmingCharacters(in: .whitespacesAndNewlines),
                    phoneNumber: phone.isEmpty ? nil : phone,
                    email: email.isEmpty ? nil : email
                ),
                adminUserId: adminUserId,
                creatorRole: canChangeCompany ? .superadmin : .admin
            )
            onCreated(gym)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct EditGymSheet: View {
    let gym: GymDTO
    let companies: [CompanyDTO]
    let canChangeCompany: Bool
    let lockedCompanyId: String?
    let service: AdminService
    var onSaved: (GymDTO) -> Void
    var onCancel: () -> Void

    @State private var name: String
    @State private var companyId: String
    @State private var address: String
    @State private var zipCode: String
    @State private var city: String
    @State private var state: String
    @State private var phone: String
    @State private var email: String
    @State private var error: String?
    @State private var isWorking = false

    init(
        gym: GymDTO,
        companies: [CompanyDTO],
        canChangeCompany: Bool,
        lockedCompanyId: String?,
        service: AdminService,
        onSaved: @escaping (GymDTO) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.gym = gym
        self.companies = companies
        self.canChangeCompany = canChangeCompany
        self.lockedCompanyId = lockedCompanyId
        self.service = service
        self.onSaved = onSaved
        self.onCancel = onCancel
        _name = State(initialValue: gym.name)
        let initialCompany = lockedCompanyId ?? gym.companyId ?? companies.first?.id ?? ""
        _companyId = State(initialValue: initialCompany)
        _address = State(initialValue: gym.address ?? "")
        _zipCode = State(initialValue: gym.zipCode ?? "")
        _city = State(initialValue: gym.city ?? "")
        _state = State(initialValue: gym.state ?? "")
        _phone = State(initialValue: gym.phoneNumber ?? "")
        _email = State(initialValue: gym.email ?? "")
    }

    private var canSave: Bool {
        !companyId.isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !address.trimmingCharacters(in: .whitespaces).isEmpty
            && !zipCode.trimmingCharacters(in: .whitespaces).isEmpty
            && !city.trimmingCharacters(in: .whitespaces).isEmpty
            && !state.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Company") {
                    if canChangeCompany {
                        Picker("Company", selection: $companyId) {
                            ForEach(companies) { company in
                                Text(company.name).tag(company.id)
                            }
                        }
                    } else {
                        Text(companies.first { $0.id == companyId }?.name ?? companyId)
                        Text("Company is fixed for gym admins.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Gym") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Zip code", text: $zipCode)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Edit gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave || isWorking)
                }
            }
            .overlay { if isWorking { ProgressView() } }
        }
    }

    private func save() async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            let effectiveCompanyId = lockedCompanyId ?? companyId
            let updated = try await service.updateGym(
                id: gym.id,
                UpdateGymRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    companyId: effectiveCompanyId,
                    address: address.trimmingCharacters(in: .whitespacesAndNewlines),
                    zipCode: zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
                    city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                    state: state.trimmingCharacters(in: .whitespacesAndNewlines),
                    phoneNumber: phone.isEmpty ? nil : phone,
                    email: email.isEmpty ? nil : email
                )
            )
            onSaved(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
