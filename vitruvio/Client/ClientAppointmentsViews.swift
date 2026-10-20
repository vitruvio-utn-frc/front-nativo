//
//  ClientAppointmentsViews.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

private enum AppointmentAction: Identifiable {
    case book(AppointmentDTO)
    case cancel(AppointmentDTO)

    var id: String {
        switch self {
        case .book(let appointment): "book-\(appointment.id)"
        case .cancel(let appointment): "cancel-\(appointment.id)"
        }
    }

    var appointment: AppointmentDTO {
        switch self {
        case .book(let appointment), .cancel(let appointment): appointment
        }
    }

    var title: String {
        switch self {
        case .book: "¿Reservar este turno?"
        case .cancel: "¿Cancelar este turno?"
        }
    }

    var confirmLabel: String {
        switch self {
        case .book: "Reservar"
        case .cancel: "Cancelar turno"
        }
    }

    var isDestructive: Bool {
        if case .cancel = self { true } else { false }
    }
}

private extension View {
    func confirmAppointmentAction(
        _ pending: Binding<AppointmentAction?>,
        perform: @escaping (AppointmentAction) -> Void
    ) -> some View {
        confirmationDialog(
            pending.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: pending.wrappedValue
        ) { action in
            Button(action.confirmLabel, role: action.isDestructive ? .destructive : nil) {
                perform(action)
            }
            Button("Volver", role: .cancel) {}
        }
    }
}

struct ClientAppointmentsHomeView: View {
    @Bindable var session: GymSessionModel
    @State private var model: ClientAppointmentsModel?
    @State private var pendingAction: AppointmentAction?

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        Group {
            if let membership = session.gymContext.activeMembership {
                appointmentsContent(membership: membership)
            } else {
                ContentUnavailableView(
                    "Ningún gimnasio seleccionado",
                    systemImage: "building.2",
                    description: Text("Elegí un gimnasio activo para ver los turnos.")
                )
            }
        }
    }

    @ViewBuilder
    private func appointmentsContent(membership: GymMembership) -> some View {
        Group {
            if let model {
                list(model)
            } else {
                ProgressView("Cargando turnos…")
            }
        }
        .task(id: membership.id) {
            if let existing = model {
                existing.updateGym(gymId: membership.gymId, gymName: membership.gymName)
                await existing.load()
            } else {
                let created = ClientAppointmentsModel(
                    memberId: session.userId,
                    gymId: membership.gymId,
                    gymName: membership.gymName,
                    api: session.session.apiClient
                )
                model = created
                await created.load()
            }
        }
    }

    @ViewBuilder
    private func list(_ model: ClientAppointmentsModel) -> some View {
        List {
            if let status = model.status {
                Section {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let error = model.lastError {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Mis turnos · \(model.gymName)") {
                if model.isLoading && model.myAppointments.isEmpty {
                    ProgressView()
                } else if model.myAppointments.isEmpty {
                    ContentUnavailableView(
                        "Sin turnos",
                        systemImage: "calendar",
                        description: Text("Reservá un turno disponible o esperá a que un entrenador te asigne uno.")
                    )
                } else {
                    ForEach(model.myAppointments) { appointment in
                        appointmentRow(appointment, model: model, bookable: false)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Cancelar", role: .destructive) {
                                    pendingAction = .cancel(appointment)
                                }
                            }
                    }
                }
            }

            Section("Disponibles") {
                if model.isLoading && model.availableSlots.isEmpty {
                    ProgressView()
                } else if model.availableSlots.isEmpty {
                    ContentUnavailableView(
                        "Sin turnos disponibles",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Cuando el gimnasio publique turnos disponibles, van a aparecer acá.")
                    )
                } else {
                    ForEach(model.availableSlots) { appointment in
                        appointmentRow(appointment, model: model, bookable: true)
                    }
                }
            }
        }
        .overlay {
            if model.isWorking {
                ProgressView()
            }
        }
        .refreshable {
            await model.load()
        }
        .navigationDestination(for: AppointmentDTO.self) { appointment in
            ClientAppointmentDetailView(appointment: appointment, model: model)
        }
        .confirmAppointmentAction($pendingAction) { action in
            Task {
                switch action {
                case .book(let appointment): await model.book(appointment)
                case .cancel(let appointment): await model.cancel(appointment)
                }
            }
        }
    }

    @ViewBuilder
    private func appointmentRow(
        _ appointment: AppointmentDTO,
        model: ClientAppointmentsModel,
        bookable: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink(value: appointment) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.activityNameById[appointment.activityId] ?? appointment.activityId)
                        .font(.body)
                    if let start = appointment.startDate {
                        Text(timeFormatter.string(from: start))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let end = appointment.endDate {
                        Text("Termina \(timeFormatter.string(from: end))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            if bookable {
                Button("Reservar") {
                    pendingAction = .book(appointment)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.isWorking)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ClientAppointmentDetailView: View {
    let appointment: AppointmentDTO
    let model: ClientAppointmentsModel

    @Environment(\.dismiss) private var dismiss
    @State private var pendingAction: AppointmentAction?

    private var isMine: Bool {
        model.myAppointments.contains { $0.id == appointment.id }
    }

    private var isAvailable: Bool {
        model.availableSlots.contains { $0.id == appointment.id }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Actividad", value: model.activityNameById[appointment.activityId] ?? appointment.activityId)
                LabeledContent("Gimnasio", value: model.gymName)
                LabeledContent("Estado", value: statusText)
            }

            Section("Horario") {
                if let start = appointment.startDate {
                    LabeledContent("Comienza", value: start.formatted(date: .abbreviated, time: .shortened))
                }
                if let end = appointment.endDate {
                    LabeledContent("Termina", value: end.formatted(date: .abbreviated, time: .shortened))
                }
                if let start = appointment.startDate, let end = appointment.endDate, end > start {
                    LabeledContent(
                        "Duración",
                        value: Duration.seconds(Int(end.timeIntervalSince(start)))
                            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
                    )
                }
            }

            if let error = model.lastError {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if isAvailable {
                Section {
                    Button("Reservar") {
                        pendingAction = .book(appointment)
                    }
                    .disabled(model.isWorking)
                }
            } else if isMine {
                Section {
                    Button("Cancelar turno", role: .destructive) {
                        pendingAction = .cancel(appointment)
                    }
                    .disabled(model.isWorking)
                }
            }
        }
        .navigationTitle(model.activityNameById[appointment.activityId] ?? "Turno")
        .navigationBarTitleDisplayMode(.inline)
        .confirmAppointmentAction($pendingAction) { action in
            Task {
                switch action {
                case .book(let appointment): await model.book(appointment)
                case .cancel(let appointment):
                    await model.cancel(appointment)
                    dismiss()
                }
            }
        }
    }

    private var statusText: String {
        if isMine { return "Reservado" }
        if isAvailable { return "Disponible" }
        return "No disponible"
    }
}
