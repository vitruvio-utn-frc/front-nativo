//
//  StaffClientsViews.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

/// Resolves the active gym for staff screens, or shows an empty state when none is selected.
struct StaffActiveGymView<Content: View>: View {
    @Bindable var session: GymSessionModel
    let emptyDescription: String
    @ViewBuilder let content: (GymMembership) -> Content

    var body: some View {
        if let membership = session.gymContext.activeMembership {
            content(membership)
        } else {
            ContentUnavailableView(
                "Ningún gimnasio seleccionado",
                systemImage: "building.2",
                description: Text(emptyDescription)
            )
        }
    }
}

struct StaffClientsHomeView: View {
    @Bindable var session: GymSessionModel
    @State private var model: StaffClientsModel?
    @State private var search = ""
    @State private var toast: Toast?

    var body: some View {
        StaffActiveGymView(session: session, emptyDescription: "Elegí un gimnasio activo para ver los clientes.") { membership in
            Group {
                if let model {
                    list(model)
                } else {
                    ProgressView("Cargando clientes…")
                }
            }
            .task(id: membership.id) {
                if let existing = model {
                    existing.updateGym(gymId: membership.gymId, gymName: membership.gymName)
                    await existing.load()
                } else {
                    let created = StaffClientsModel(
                        gymId: membership.gymId,
                        gymName: membership.gymName,
                        api: session.session.apiClient
                    )
                    model = created
                    await created.load()
                }
            }
        }
        .toast($toast)
    }

    @ViewBuilder
    private func list(_ model: StaffClientsModel) -> some View {
        let visible = model.clients.filter { matches($0) }
        List {
            Section("Clientes · \(model.gymName)") {
                if model.isLoading && model.clients.isEmpty {
                    ProgressView()
                } else if model.clients.isEmpty {
                    ContentUnavailableView(
                        "Sin clientes",
                        systemImage: "person.2.slash",
                        description: Text("Todavía no hay clientes en este gimnasio.")
                    )
                } else if visible.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    ForEach(visible) { entry in
                        NavigationLink {
                            StaffClientDetailView(session: session, client: entry.user, gymId: model.gymId)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.user.displayName)
                                if let email = entry.user.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Buscar cliente")
        .refreshable { await model.load() }
        .onChange(of: model.feedbackID) {
            if let error = model.lastError { toast = .error(error) }
        }
    }

    private func matches(_ entry: AdminDirectoryUser) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let haystack = [entry.user.displayName, entry.user.email ?? "", entry.user.idNumber.map(String.init) ?? ""]
        return haystack.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

struct StaffClientDetailView: View {
    @Bindable var session: GymSessionModel
    let client: UserDTO
    let gymId: String

    @State private var model: StaffClientDetailModel?
    @State private var showNewPlan = false
    @State private var planPendingDelete: TrainingPlanDTO?
    @State private var toast: Toast?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(client.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let created = StaffClientDetailModel(
                    client: client,
                    gymId: gymId,
                    trainerId: session.userId,
                    api: session.session.apiClient
                )
                model = created
                await created.load()
            }
        }
        .toast($toast)
    }

    @ViewBuilder
    private func content(_ model: StaffClientDetailModel) -> some View {
        List {
            Section("Datos") {
                LabeledContent("Nombre", value: client.displayName)
                if let email = client.email { LabeledContent("Email", value: email) }
                if let idNumber = client.idNumber { LabeledContent("DNI", value: String(idNumber)) }
                if let height = client.height { LabeledContent("Altura", value: "\(height.formatted()) cm") }
                if let weight = client.weight { LabeledContent("Peso", value: "\(weight.formatted()) kg") }
            }

            Section("Membresías") {
                if model.isLoading && model.memberships.isEmpty {
                    ProgressView()
                } else if model.memberships.isEmpty {
                    Text("Sin membresías en este gimnasio")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.memberships) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                if let end = item.userMembership.endDate {
                                    Text("Vence \(end.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(item.userMembership.isActive ? "Activa" : "Inactiva")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.userMembership.isActive ? .green : .secondary)
                        }
                    }
                }
            }

            Section {
                if model.isLoading && model.plans.isEmpty {
                    ProgressView()
                } else if model.plans.isEmpty {
                    Text("Todavía no tiene planes")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.plans) { plan in
                        NavigationLink {
                            StaffPlanView(session: session, plan: plan, memberId: client.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.name)
                                if let description = plan.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !plan.durationLabel.isEmpty {
                                    Text(plan.durationLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Eliminar", role: .destructive) { planPendingDelete = plan }
                        }
                    }
                }
            } header: {
                Text("Planes de entrenamiento")
            }
        }
        .refreshable { await model.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nuevo plan", systemImage: "plus") { showNewPlan = true }
            }
        }
        .onChange(of: model.feedbackID) {
            if let error = model.lastError { toast = .error(error) }
        }
        .sheet(isPresented: $showNewPlan) {
            StaffPlanFormSheet(title: "Nuevo plan", plan: nil) { name, description, days, start in
                let request = TrainingPlanRequest(
                    memberId: client.id,
                    trainerId: model.trainerId,
                    name: name,
                    description: description,
                    durationDays: days,
                    startDate: start,
                    endDate: start.flatMap { Calendar.current.date(byAdding: .day, value: days, to: $0) }
                )
                let created = await model.createPlan(request)
                if created != nil { toast = .success("Plan creado") }
                return created != nil
            }
        }
        .confirmationDialog(
            "¿Eliminar plan?",
            isPresented: Binding(
                get: { planPendingDelete != nil },
                set: { if !$0 { planPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: planPendingDelete
        ) { plan in
            Button("Eliminar “\(plan.name)”", role: .destructive) {
                Task {
                    if await model.deletePlan(plan) { toast = .success("Plan eliminado") }
                }
            }
            Button("Volver", role: .cancel) {}
        } message: { _ in
            Text("Esto elimina el plan de la API. Si todavía tiene sesiones, el backend puede rechazarlo.")
        }
    }
}
