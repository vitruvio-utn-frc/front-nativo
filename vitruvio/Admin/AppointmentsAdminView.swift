//
//  AppointmentsAdminView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct AppointmentsAdminView: View {
    @Bindable var admin: AdminWorkspaceModel
    @State private var appointments: [AppointmentDTO] = []
    @State private var activities: [ActivityDTO] = []
    @State private var activityTypes: [ActivityTypeDTO] = []
    @State private var showCreateActivityType = false
    @State private var showCreateActivity = false
    @State private var showCreateAppointment = false
    @State private var error: String?
    @State private var status: String?
    @State private var isWorking = false

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var activityNameById: [String: String] {
        Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0.name) })
    }

    private var typeNameById: [Int: String] {
        Dictionary(uniqueKeysWithValues: activityTypes.map { ($0.id, $0.name) })
    }

    var body: some View {
        List {
            if let status {
                Section { Text(status).foregroundStyle(.secondary).font(.caption) }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }

            Section("Tipos de actividad") {
                if activityTypes.isEmpty {
                    ContentUnavailableView(
                        "Todavía no hay tipos de actividad",
                        systemImage: "tag",
                        description: Text("Tocá + → Agregar tipo de actividad antes de crear actividades.")
                    )
                } else {
                    ForEach(activityTypes) { type in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.name)
                            if let description = type.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Actividades") {
                if activities.isEmpty {
                    ContentUnavailableView(
                        "Todavía no hay actividades",
                        systemImage: "figure.run",
                        description: Text("Tocá + → Agregar actividad antes de crear turnos.")
                    )
                } else {
                    ForEach(activities) { activity in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.name)
                            if let typeId = activity.activityTypeId {
                                Text(typeNameById[typeId] ?? "tipo \(typeId)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Turnos · \(admin.gymName)") {
                if appointments.isEmpty {
                    ContentUnavailableView(
                        "Todavía no hay turnos",
                        systemImage: "calendar",
                        description: Text("Tocá + → Agregar turno.")
                    )
                } else {
                    ForEach(appointments) { appt in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activityNameById[appt.activityId] ?? appt.activityId)
                            if let start = appt.startDate {
                                Text(timeFormatter.string(from: start))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let end = appt.endDate {
                                Text("Termina \(timeFormatter.string(from: end))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Eliminar", role: .destructive) {
                                Task { await delete(appt.id) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Turnos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCreateActivityType = true
                    } label: {
                        Label("Agregar tipo de actividad", systemImage: "tag")
                    }
                    Button {
                        showCreateActivity = true
                    } label: {
                        Label("Agregar actividad", systemImage: "figure.run")
                    }
                    .disabled(activityTypes.isEmpty)
                    Button {
                        showCreateAppointment = true
                    } label: {
                        Label("Agregar turno", systemImage: "calendar.badge.plus")
                    }
                    .disabled(activities.isEmpty)
                } label: {
                    Label("Agregar", systemImage: "plus")
                }
                .disabled(isWorking)
            }
        }
        .overlay { if isWorking { ProgressView() } }
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showCreateActivityType) {
            CreateActivityTypeSheet(service: admin.service) { created in
                status = "Tipo de actividad “\(created.name)” creado."
                showCreateActivityType = false
                Task { await reload() }
            } onCancel: {
                showCreateActivityType = false
            }
        }
        .sheet(isPresented: $showCreateActivity) {
            CreateActivitySheet(service: admin.service, activityTypes: activityTypes) { created in
                status = "Actividad “\(created.name)” creada."
                showCreateActivity = false
                Task { await reload() }
            } onCancel: {
                showCreateActivity = false
            }
        }
        .sheet(isPresented: $showCreateAppointment) {
            CreateAppointmentSheet(
                service: admin.service,
                gymId: admin.gymId,
                gymName: admin.gymName,
                activities: activities
            ) { created in
                let name = activityNameById[created.activityId] ?? created.activityId
                status = "Turno de “\(name)” creado en \(admin.gymName)."
                showCreateAppointment = false
                Task { await reload() }
            } onCancel: {
                showCreateAppointment = false
            }
        }
    }

    private func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let a = admin.service.listAppointments(gymId: admin.gymId)
            async let act = admin.service.listActivities()
            async let types = admin.service.listActivityTypes()
            (appointments, activities, activityTypes) = try await (a, act, types)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ id: String) async {
        do {
            try await admin.service.deleteAppointment(id: id)
            status = "Turno eliminado"
            error = nil
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct CreateActivityTypeSheet: View {
    let service: AdminService
    var onCreated: (ActivityTypeDTO) -> Void
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
                Section("Tipo de actividad") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción (opcional)", text: $description)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Nuevo tipo de actividad")
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
            let created = try await service.createActivityType(
                CreateActivityTypeRequest(
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

private struct CreateActivitySheet: View {
    let service: AdminService
    let activityTypes: [ActivityTypeDTO]
    var onCreated: (ActivityDTO) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var activityTypeId: Int?
    @State private var error: String?
    @State private var isWorking = false

    init(
        service: AdminService,
        activityTypes: [ActivityTypeDTO],
        onCreated: @escaping (ActivityDTO) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.service = service
        self.activityTypes = activityTypes
        self.onCreated = onCreated
        self.onCancel = onCancel
        _activityTypeId = State(initialValue: activityTypes.first?.id)
    }

    private var canSave: Bool {
        activityTypeId != nil
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de actividad") {
                    Picker("Tipo", selection: $activityTypeId) {
                        ForEach(activityTypes) { type in
                            Text(type.name).tag(Optional(type.id))
                        }
                    }
                }
                Section("Actividad") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción (opcional)", text: $description)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Nueva actividad")
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
        guard let activityTypeId else { return }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            let created = try await service.createActivity(
                CreateActivityRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    activityTypeId: activityTypeId
                )
            )
            onCreated(created)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct CreateAppointmentSheet: View {
    let service: AdminService
    let gymId: String
    let gymName: String
    let activities: [ActivityDTO]
    var onCreated: (AppointmentDTO) -> Void
    var onCancel: () -> Void

    @State private var activityId: String
    @State private var start = Date().addingTimeInterval(3600)
    @State private var end = Date().addingTimeInterval(7200)
    @State private var error: String?
    @State private var isWorking = false

    init(
        service: AdminService,
        gymId: String,
        gymName: String,
        activities: [ActivityDTO],
        onCreated: @escaping (AppointmentDTO) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.service = service
        self.gymId = gymId
        self.gymName = gymName
        self.activities = activities
        self.onCreated = onCreated
        self.onCancel = onCancel
        _activityId = State(initialValue: activities.first?.id ?? "")
    }

    private var canSave: Bool {
        !activityId.isEmpty && end > start
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gimnasio") {
                    Text(gymName)
                    Text("El turno se creará en el gimnasio activo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Actividad") {
                    Picker("Actividad", selection: $activityId) {
                        ForEach(activities) { activity in
                            Text(activity.name).tag(activity.id)
                        }
                    }
                }
                Section("Horario") {
                    DatePicker("Inicio", selection: $start)
                    DatePicker("Fin", selection: $end)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Nuevo turno")
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
            let created = try await service.createAppointment(
                CreateAppointmentRequest(
                    gymId: gymId,
                    activityId: activityId,
                    startDate: start,
                    endDate: end
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
