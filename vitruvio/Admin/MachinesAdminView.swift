//
//  MachinesAdminView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct MachinesAdminView: View {
    @Bindable var admin: AdminWorkspaceModel
    @State private var machines: [MachineDTO] = []
    @State private var types: [MachineTypeDTO] = []
    @State private var showCreateType = false
    @State private var showCreateMachine = false
    @State private var editingType: MachineTypeDTO?
    @State private var error: String?
    @State private var status: String?
    @State private var isWorking = false

    private var typeNameById: [Int: String] {
        Dictionary(uniqueKeysWithValues: types.map { ($0.id, $0.name) })
    }

    var body: some View {
        List {
            if let status {
                Section { Text(status).foregroundStyle(.secondary).font(.caption) }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }

            Section("Tipos") {
                if types.isEmpty {
                    ContentUnavailableView(
                        "Todavía no hay tipos de máquina",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Tocá + → Agregar tipo antes de crear máquinas.")
                    )
                } else {
                    ForEach(types) { type in
                        Button {
                            editingType = type
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.name)
                                    if let description = type.description, !description.isEmpty {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "pencil")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Máquinas") {
                if machines.isEmpty {
                    ContentUnavailableView(
                        "Todavía no hay máquinas",
                        systemImage: "dumbbell",
                        description: Text("Tocá + → Agregar máquina.")
                    )
                } else {
                    ForEach(machines) { machine in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(machine.displayName.isEmpty ? machine.id : machine.displayName)
                            if let typeId = machine.machineTypeId {
                                Text(typeNameById[typeId] ?? "tipo \(typeId)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Eliminar", role: .destructive) {
                                Task { await delete(machine.id) }
                            }
                        }
                    }
                }
            }

            Section {
                Text("Las máquinas de la API son globales (sin gymId). Se administran acá por comodidad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Máquinas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCreateType = true
                    } label: {
                        Label("Agregar tipo", systemImage: "tag")
                    }
                    Button {
                        showCreateMachine = true
                    } label: {
                        Label("Agregar máquina", systemImage: "dumbbell")
                    }
                    .disabled(types.isEmpty)
                } label: {
                    Label("Agregar", systemImage: "plus")
                }
                .disabled(isWorking)
            }
        }
        .overlay { if isWorking { ProgressView() } }
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showCreateType) {
            CreateMachineTypeSheet(service: admin.service) { created in
                status = "Tipo “\(created.name)” creado."
                showCreateType = false
                Task { await reload() }
            } onCancel: {
                showCreateType = false
            }
        }
        .sheet(item: $editingType) { type in
            EditMachineTypeSheet(type: type, service: admin.service) { updated in
                status = "Tipo “\(updated.name)” actualizado."
                editingType = nil
                Task { await reload() }
            } onCancel: {
                editingType = nil
            }
        }
        .sheet(isPresented: $showCreateMachine) {
            CreateMachineSheet(service: admin.service, types: types) { created in
                let label = created.displayName.isEmpty ? created.id : created.displayName
                status = "Máquina “\(label)” creada."
                showCreateMachine = false
                Task { await reload() }
            } onCancel: {
                showCreateMachine = false
            }
        }
    }

    private func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let m = admin.service.listMachines()
            async let t = admin.service.listMachineTypes()
            (machines, types) = try await (m, t)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ id: String) async {
        do {
            try await admin.service.deleteMachine(id: id)
            status = "Máquina eliminada"
            error = nil
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct CreateMachineTypeSheet: View {
    let service: AdminService
    var onCreated: (MachineTypeDTO) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var error: String?
    @State private var isWorking = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de máquina") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción (opcional)", text: $description)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Nuevo tipo")
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
            let created = try await service.createMachineType(
                CreateMachineTypeRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            )
            onCreated(created)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct EditMachineTypeSheet: View {
    let type: MachineTypeDTO
    let service: AdminService
    var onSaved: (MachineTypeDTO) -> Void
    var onCancel: () -> Void

    @State private var name: String
    @State private var description: String
    @State private var error: String?
    @State private var isWorking = false

    init(
        type: MachineTypeDTO,
        service: AdminService,
        onSaved: @escaping (MachineTypeDTO) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.type = type
        self.service = service
        self.onSaved = onSaved
        self.onCancel = onCancel
        _name = State(initialValue: type.name)
        _description = State(initialValue: type.description ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de máquina") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción (opcional)", text: $description)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Editar tipo")
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
            let updated = try await service.updateMachineType(
                id: type.id,
                UpdateMachineTypeRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            )
            onSaved(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct CreateMachineSheet: View {
    let service: AdminService
    let types: [MachineTypeDTO]
    var onCreated: (MachineDTO) -> Void
    var onCancel: () -> Void

    @State private var typeId: Int?
    @State private var brand = ""
    @State private var model = ""
    @State private var error: String?
    @State private var isWorking = false

    init(
        service: AdminService,
        types: [MachineTypeDTO],
        onCreated: @escaping (MachineDTO) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.service = service
        self.types = types
        self.onCreated = onCreated
        self.onCancel = onCancel
        _typeId = State(initialValue: types.first?.id)
    }

    private var canSave: Bool {
        typeId != nil
            && !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo de máquina", selection: $typeId) {
                        ForEach(types) { type in
                            Text(type.name).tag(Optional(type.id))
                        }
                    }
                }
                Section("Máquina") {
                    TextField("Marca", text: $brand)
                    TextField("Modelo", text: $model)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Nueva máquina")
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
        guard let typeId else { return }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            let created = try await service.createMachine(
                CreateMachineRequest(
                    machineTypeId: typeId,
                    brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: model.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            onCreated(created)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
