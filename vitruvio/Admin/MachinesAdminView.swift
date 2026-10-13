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
    @State private var brand = ""
    @State private var model = ""
    @State private var typeId: Int?
    @State private var newTypeName = ""
    @State private var error: String?
    @State private var isWorking = false

    var body: some View {
        List {
            Section("Machine type") {
                if types.isEmpty {
                    TextField("New type name", text: $newTypeName)
                    Button("Create type") { Task { await createType() } }
                        .disabled(newTypeName.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Picker("Type", selection: $typeId) {
                        Text("Select").tag(Optional<Int>.none)
                        ForEach(types) { type in
                            Text(type.name).tag(Optional(type.id))
                        }
                    }
                }
            }

            Section("Add machine") {
                TextField("Brand", text: $brand)
                TextField("Model", text: $model)
                Button("Create") { Task { await createMachine() } }
                    .disabled(brand.isEmpty || model.isEmpty || typeId == nil || isWorking)
            }

            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }

            Section {
                Text("API machines are global (no gymId). Managed here for admin convenience.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Machines") {
                if machines.isEmpty {
                    Text("No machines yet").foregroundStyle(.secondary)
                }
                ForEach(machines) { machine in
                    VStack(alignment: .leading) {
                        Text(machine.displayName.isEmpty ? machine.id : machine.displayName)
                        if let typeId = machine.machineTypeId {
                            Text("type \(typeId)").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            Task { await delete(machine.id) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Machines")
        .overlay { if isWorking { ProgressView() } }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let m = admin.service.listMachines()
            async let t = admin.service.listMachineTypes()
            (machines, types) = try await (m, t)
            if typeId == nil { typeId = types.first?.id }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func createType() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let created = try await admin.service.createMachineType(
                CreateMachineTypeRequest(name: newTypeName.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            newTypeName = ""
            typeId = created.id
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func createMachine() async {
        guard let typeId else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await admin.service.createMachine(
                CreateMachineRequest(
                    machineTypeId: typeId,
                    brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: model.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            brand = ""
            model = ""
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ id: String) async {
        do {
            try await admin.service.deleteMachine(id: id)
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
