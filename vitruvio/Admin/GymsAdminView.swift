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
                    Text("Elegí una empresa o tocá + → Agregar empresa.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Text("Esta cuenta de admin no tiene empresa en el gimnasio activo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Gimnasios")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if canManageCompanies {
                    Menu {
                        Button {
                            showCreateCompany = true
                        } label: {
                            Label("Agregar empresa", systemImage: "building.2")
                        }
                        Button {
                            showCreateGym = true
                        } label: {
                            Label("Agregar gimnasio", systemImage: "dumbbell")
                        }
                        .disabled(!hasCompanyScope)
                    } label: {
                        Label("Agregar", systemImage: "plus")
                    }
                    .disabled(isWorking)
                } else {
                    Button {
                        showCreateGym = true
                    } label: {
                        Label("Agregar gimnasio", systemImage: "plus")
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
                status = "Empresa “\(created.name)” creada. Tocá + para agregar un gimnasio."
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
                status = "“\(created.name)” creado. Cambiá de gimnasio o rol si necesitás abrirlo."
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
                status = "“\(updated.name)” actualizado"
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
            "¿Eliminar gimnasio?",
            isPresented: Binding(
                get: { gymPendingDelete != nil },
                set: { if !$0 { gymPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar “\(gymPendingDelete?.name ?? "gimnasio")”", role: .destructive) {
                if let gym = gymPendingDelete {
                    Task { await deleteGym(gym) }
                }
            }
            Button("Cancelar", role: .cancel) {
                gymPendingDelete = nil
            }
        } message: {
            Text("Esto elimina el gimnasio de la API. Los roles o vínculos relacionados pueden fallar si el backend todavía lo referencia.")
        }
    }

    @ViewBuilder
    private var superadminCompanySection: some View {
        Section("Empresa") {
            if companies.isEmpty {
                ContentUnavailableView(
                    "Todavía no hay empresas",
                    systemImage: "building.2",
                    description: Text("Tocá + → Agregar empresa.")
                )
            } else {
                Picker("Empresa", selection: $companyId) {
                    Text("Seleccionar").tag("")
                    ForEach(companies) { company in
                        Text(company.name).tag(company.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var adminCompanySection: some View {
        Section("Empresa") {
            Text(selectedCompanyName)
            Text("Los admins de gimnasio solo pueden administrar gimnasios de esta empresa.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var gymListSection: some View {
        Section("Gimnasios · \(selectedCompanyName)") {
            if gymsForScope.isEmpty {
                ContentUnavailableView(
                    "Todavía no hay gimnasios",
                    systemImage: "building.2",
                    description: Text("Tocá + para crear un gimnasio en esta empresa.")
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
                    Button("Eliminar", role: .destructive) {
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
                    error = "El gimnasio activo no tiene empresa; no se pueden administrar gimnasios."
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
                error = "Los admins de gimnasio solo pueden eliminar gimnasios de su empresa."
                return
            }
            try await admin.service.deleteGym(id: gym.id)
            status = "“\(gym.name)” eliminado"
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
                Section("Empresa") {
                    TextField("Nombre", text: $name)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Nueva empresa")
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
                Section("Empresa") {
                    if canChangeCompany {
                        Picker("Empresa", selection: $companyId) {
                            ForEach(companies) { company in
                                Text(company.name).tag(company.id)
                            }
                        }
                    } else {
                        Text(companies.first { $0.id == companyId }?.name ?? companyId)
                        Text("La empresa es fija para los admins de gimnasio.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Gimnasio") {
                    TextField("Nombre", text: $name)
                    TextField("Dirección", text: $address)
                    TextField("Código postal", text: $zipCode)
                    TextField("Ciudad", text: $city)
                    TextField("Provincia", text: $state)
                    TextField("Teléfono", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Nuevo gimnasio")
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
                Section("Empresa") {
                    if canChangeCompany {
                        Picker("Empresa", selection: $companyId) {
                            ForEach(companies) { company in
                                Text(company.name).tag(company.id)
                            }
                        }
                    } else {
                        Text(companies.first { $0.id == companyId }?.name ?? companyId)
                        Text("La empresa es fija para los admins de gimnasio.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Gimnasio") {
                    TextField("Nombre", text: $name)
                    TextField("Dirección", text: $address)
                    TextField("Código postal", text: $zipCode)
                    TextField("Ciudad", text: $city)
                    TextField("Provincia", text: $state)
                    TextField("Teléfono", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Editar gimnasio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
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
