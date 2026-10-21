//
//  ClientMembershipProfileViews.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct ClientMembershipsView: View {
    @Bindable var session: GymSessionModel
    @State private var model: ClientMembershipsModel?
    @State private var showEnroll = false
    @State private var toast: Toast?

    var body: some View {
        Group {
            if let membership = session.gymContext.activeMembership {
                content(membership: membership)
            } else {
                ContentUnavailableView(
                    "Ningún gimnasio seleccionado",
                    systemImage: "building.2",
                    description: Text("Elegí un gimnasio activo para ver tus membresías.")
                )
            }
        }
        .navigationTitle("Membresías")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(membership: GymMembership) -> some View {
        Group {
            if let model {
                list(model)
            } else {
                ProgressView("Cargando membresías…")
            }
        }
        .task(id: membership.id) {
            if let existing = model {
                existing.updateGym(gymId: membership.gymId, gymName: membership.gymName)
                await existing.load()
            } else {
                let created = ClientMembershipsModel(
                    userId: session.userId,
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
    private func list(_ model: ClientMembershipsModel) -> some View {
        List {
            Section(model.gymName) {
                if model.isLoading && model.items.isEmpty {
                    ProgressView()
                } else if model.items.isEmpty {
                    ContentUnavailableView(
                        "Sin membresías activas",
                        systemImage: "creditcard.trianglebadge.exclamationmark",
                        description: Text("No tenés membresías en este gimnasio. Tocá + para contratar una.")
                    )
                } else {
                    ForEach(model.items) { item in
                        NavigationLink {
                            ClientMembershipDetailView(item: item, model: model) {
                                toast = .success("Membresía dada de baja")
                            }
                        } label: {
                            ClientMembershipRow(item: item)
                        }
                    }
                }
            }
        }
        .refreshable { await model.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Contratar membresía", systemImage: "plus") { showEnroll = true }
            }
        }
        .onChange(of: model.feedbackID) {
            // While the enroll sheet is open it reports its own errors.
            if !showEnroll, let error = model.lastError { toast = .error(error) }
        }
        .toast($toast)
        .sheet(isPresented: $showEnroll) {
            ClientEnrollMembershipSheet(model: model) {
                toast = .success("Membresía contratada")
            }
        }
    }
}

private struct ClientEnrollMembershipSheet: View {
    let model: ClientMembershipsModel
    let onEnrolled: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pending: MembershipDTO?
    @State private var toast: Toast?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if model.available.isEmpty {
                        ContentUnavailableView(
                            "Sin planes disponibles",
                            systemImage: "creditcard",
                            description: Text("Este gimnasio todavía no tiene membresías a la venta.")
                        )
                    } else {
                        ForEach(model.available) { membership in
                            planRow(membership)
                        }
                    }
                } header: {
                    Text(model.gymName)
                } footer: {
                    Text("El pago en línea todavía no está disponible: la membresía se activa al contratarla.")
                }
            }
            .navigationTitle("Contratar membresía")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .overlay { if model.isWorking { ProgressView() } }
            .onChange(of: model.feedbackID) {
                if let error = model.lastError { toast = .error(error) }
            }
            .toast($toast)
            .confirmationDialog(
                "¿Contratar esta membresía?",
                isPresented: Binding(
                    get: { pending != nil },
                    set: { if !$0 { pending = nil } }
                ),
                titleVisibility: .visible,
                presenting: pending
            ) { membership in
                Button("Contratar “\(membership.name)”") {
                    Task {
                        if await model.enroll(in: membership) {
                            onEnrolled()
                            dismiss()
                        }
                    }
                }
                Button("Volver", role: .cancel) {}
            } message: { membership in
                Text("Comienza hoy y dura \(membership.durationLabel).")
            }
        }
        .interactiveDismissDisabled(model.isWorking)
    }

    @ViewBuilder
    private func planRow(_ membership: MembershipDTO) -> some View {
        let isActive = model.isActive(membership)
        Button {
            pending = membership
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(membership.name)
                        .font(.headline)
                    Spacer()
                    if isActive {
                        Text("Activa")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
                if let description = membership.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(membership.price.formatted(.currency(code: "ARS")))
                    Text("·")
                    Text(membership.durationLabel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .foregroundStyle(.primary)
        .disabled(isActive || model.isWorking)
    }
}

private struct ClientMembershipRow: View {
    let item: ClientMembershipItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                ClientMembershipStatusBadge(isActive: item.userMembership.isActive)
            }
            if let end = item.userMembership.endDate {
                Text("Vence \(end.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ClientMembershipStatusBadge: View {
    let isActive: Bool

    var body: some View {
        Text(isActive ? "Activa" : "Inactiva")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? .green : .secondary)
    }
}

struct ClientMembershipDetailView: View {
    let item: ClientMembershipItem
    let model: ClientMembershipsModel
    let onCancelled: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmCancel = false
    @State private var toast: Toast?

    private var activeGymName: String { model.gymName }

    var body: some View {
        List {
            Section {
                LabeledContent("Estado") {
                    ClientMembershipStatusBadge(isActive: item.userMembership.isActive)
                }
                if let remaining = remainingDays {
                    LabeledContent("Días restantes", value: String(remaining))
                }
            }

            if let description = item.membership?.description, !description.isEmpty {
                Section("Descripción") {
                    Text(description)
                }
            }

            Section("Vigencia") {
                if let start = item.userMembership.startDate {
                    LabeledContent("Inicio", value: start.formatted(date: .long, time: .omitted))
                }
                if let end = item.userMembership.endDate {
                    LabeledContent("Vencimiento", value: end.formatted(date: .long, time: .omitted))
                }
                if let duration = item.membership?.durationLabel, !duration.isEmpty {
                    LabeledContent("Duración del plan", value: duration)
                }
            }

            if let price = item.membership?.price, price > 0 {
                Section("Plan") {
                    LabeledContent("Precio", value: price.formatted(.currency(code: "ARS")))
                }
            }

            Section("Disponible en") {
                if item.gymNames.isEmpty {
                    Text("Sin gimnasios vinculados")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(item.gymNames, id: \.self) { name in
                        HStack {
                            Label(name, systemImage: "building.2")
                            if name == activeGymName {
                                Spacer()
                                Text("Activo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if model.canCancel(item) {
                Section {
                    Button("Dar de baja", role: .destructive) { confirmCancel = true }
                        .disabled(model.isWorking)
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if model.isWorking { ProgressView() } }
        .onChange(of: model.feedbackID) {
            if let error = model.lastError { toast = .error(error) }
        }
        .toast($toast)
        .confirmationDialog(
            "¿Dar de baja esta membresía?",
            isPresented: $confirmCancel,
            titleVisibility: .visible
        ) {
            Button("Dar de baja “\(item.name)”", role: .destructive) {
                Task {
                    if await model.cancel(item) {
                        onCancelled()
                        dismiss()
                    }
                }
            }
            Button("Volver", role: .cancel) {}
        } message: {
            Text("Vence hoy y deja de estar activa. Queda en tu historial.")
        }
    }

    private var remainingDays: Int? {
        guard item.userMembership.isActive, let end = item.userMembership.endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0
        return max(days, 0)
    }
}

struct ClientProfileView: View {
    @Bindable var session: GymSessionModel
    @State private var model: ClientProfileModel?
    @State private var isEditing = false
    @State private var toast: Toast?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView("Cargando perfil…")
            }
        }
        .navigationTitle("Mi perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") {
                    model?.discardChanges()
                    isEditing = true
                }
                .disabled(model?.user == nil)
            }
        }
        .task {
            if model == nil {
                let created = ClientProfileModel(userId: session.userId, api: session.session.apiClient)
                model = created
                await created.load()
            }
        }
        .toast($toast)
    }

    @ViewBuilder
    private func content(_ model: ClientProfileModel) -> some View {
        List {
            if let user = model.user {
                Section("Datos personales") {
                    LabeledContent("Nombre", value: user.firstName ?? "—")
                    LabeledContent("Apellido", value: user.lastName ?? "—")
                    LabeledContent("Email", value: user.email ?? "—")
                    if let birthDate = user.birthDate {
                        LabeledContent("Nacimiento", value: birthDate.formatted(date: .long, time: .omitted))
                    }
                }

                Section("Medidas") {
                    if let height = user.height {
                        LabeledContent("Altura", value: "\(height.formatted()) cm")
                    }
                    if let weight = user.weight {
                        LabeledContent("Peso", value: "\(weight.formatted()) kg")
                    }
                }

                Section("Cuenta") {
                    if let idNumber = user.idNumber {
                        LabeledContent("DNI", value: String(idNumber))
                    }
                    if let genderName = model.genderName {
                        LabeledContent("Género", value: genderName)
                    }
                }
            } else if model.isLoading {
                ProgressView()
            } else {
                Button("Reintentar") { Task { await model.load() } }
            }
        }
        .refreshable { await model.load() }
        .onChange(of: model.feedbackID) {
            // While the edit sheet is open it reports its own errors.
            if !isEditing, let error = model.lastError {
                toast = .error(error)
            }
        }
        .sheet(isPresented: $isEditing) {
            ClientProfileEditSheet(model: model) {
                isEditing = false
                toast = .success("Perfil actualizado")
            }
        }
    }
}

private struct ClientProfileEditSheet: View {
    @Bindable var model: ClientProfileModel
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var toast: Toast?
    @State private var confirmSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos personales") {
                    TextField("Nombre", text: $model.draft.firstName)
                        .textContentType(.givenName)
                    TextField("Apellido", text: $model.draft.lastName)
                        .textContentType(.familyName)
                    TextField("Email", text: $model.draft.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    DatePicker(
                        "Nacimiento",
                        selection: $model.draft.birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }

                Section("Medidas") {
                    LabeledContent("Altura (cm)") {
                        TextField("0", text: $model.draft.height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Peso (kg)") {
                        TextField("0", text: $model.draft.weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        model.discardChanges()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { confirmSave = true }
                        .disabled(!model.hasChanges || model.isSaving)
                }
            }
            .confirmationDialog(
                "¿Guardar los cambios del perfil?",
                isPresented: $confirmSave,
                titleVisibility: .visible
            ) {
                Button("Guardar") {
                    Task {
                        if await model.save() { onSaved() }
                    }
                }
                Button("Volver", role: .cancel) {}
            }
            .overlay { if model.isSaving { ProgressView() } }
            .onChange(of: model.feedbackID) {
                if let error = model.lastError { toast = .error(error) }
            }
            .toast($toast)
        }
        .interactiveDismissDisabled(model.isSaving)
    }
}
