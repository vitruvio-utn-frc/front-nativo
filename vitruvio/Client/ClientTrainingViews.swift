//
//  ClientTrainingViews.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct ClientTrainingHomeView: View {
    @Bindable var session: GymSessionModel
    @State private var model: ClientTrainingModel?
    @State private var showActiveSession = false

    var body: some View {
        Group {
            if let model {
                plansList(model)
            } else {
                ProgressView("Cargando entrenamiento…")
            }
        }
        .task {
            if model == nil {
                model = ClientTrainingModel(
                    memberId: session.userId,
                    api: session.session.apiClient
                )
            }
            await model?.loadPlans()
            await CompanionPhoneGateway.shared.publish()
        }
    }

    @ViewBuilder
    private func plansList(_ model: ClientTrainingModel) -> some View {
        List {
            if let snapshot = model.activeSession.snapshot {
                Section("Sesión activa") {
                    Button {
                        showActiveSession = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.planName ?? "Entrenamiento")
                            Text("\(snapshot.executionCount) ejercicios · \(snapshot.setCount) series")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Finalizar sesión", role: .destructive) {
                        model.endSession()
                    }
                }
            }

            if model.pendingOfflineCount > 0 {
                Section {
                    Text("\(model.pendingOfflineCount) acción(es) sin conexión pendientes de sincronizar")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let status = model.status {
                Section { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
            if let error = model.lastError {
                Section { Text(error).font(.caption).foregroundStyle(.red) }
            }

            Section("Mis planes") {
                if model.isLoading && model.plans.isEmpty {
                    ProgressView()
                } else if model.plans.isEmpty {
                    ContentUnavailableView(
                        "Sin planes de entrenamiento",
                        systemImage: "list.clipboard",
                        description: Text("Cuando un entrenador te asigne un plan, va a aparecer acá.")
                    )
                } else {
                    ForEach(model.plans) { plan in
                        NavigationLink(value: TrainingRoute.plan(plan.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name)
                                if let description = plan.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !plan.durationLabel.isEmpty {
                                    Text(plan.durationLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: TrainingRoute.self) { route in
            switch route {
            case .plan(let id):
                if let plan = model.plans.first(where: { $0.id == id }) {
                    TrainingPlanDetailView(model: model, plan: plan) {
                        showActiveSession = true
                    }
                } else {
                    Text("Plan no encontrado")
                }
            case .session(let id):
                if model.isActiveSession(id) {
                    ActiveTrainingSessionView(model: model)
                } else {
                    PastTrainingSessionView(model: model, sessionId: id)
                }
            }
        }
        .navigationDestination(isPresented: $showActiveSession) {
            ActiveTrainingSessionView(model: model)
        }
        .refreshable { await model.loadPlans() }
        .overlay { if model.isWorking { ProgressView() } }
        .task(id: model.network.isOnline) {
            await model.onNetworkTick()
        }
    }
}

private enum TrainingRoute: Hashable {
    case plan(String)
    case session(String)
}

struct TrainingPlanDetailView: View {
    @Bindable var model: ClientTrainingModel
    let plan: TrainingPlanDTO
    var onStarted: () -> Void

    var body: some View {
        List {
            Section("Plan") {
                LabeledContent("Nombre", value: plan.name)
                if let description = plan.description, !description.isEmpty {
                    Text(description)
                }
                if !plan.durationLabel.isEmpty {
                    LabeledContent("Duración", value: plan.durationLabel)
                }
            }

            Section("Sesiones de este plan") {
                if model.planSessions.isEmpty {
                    Text("Sin sesiones previas: iniciá una para empezar a registrar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.planSessions) { session in
                        NavigationLink(value: TrainingRoute.session(session.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.isActiveSession(session.id) ? "Sesión activa" : "Sesión")
                                    .font(.subheadline)
                                Text(session.id)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            if let error = model.lastError {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Iniciar") {
                    Task {
                        if await model.startSession(plan: plan) != nil {
                            onStarted()
                        }
                    }
                }
                .disabled(model.isWorking)
            }
        }
        .overlay { if model.isWorking || model.isLoading { ProgressView() } }
        .task { await model.loadPlanDetail(planId: plan.id) }
        .refreshable { await model.loadPlanDetail(planId: plan.id) }
    }
}

struct PastTrainingSessionView: View {
    @Bindable var model: ClientTrainingModel
    let sessionId: String

    var body: some View {
        List {
            Section("Sesión") {
                LabeledContent("ID de sesión", value: sessionId)
            }
            if let error = model.lastError {
                Section { Text(error).font(.caption).foregroundStyle(.red) }
            }
            Section("Ejercicios") {
                if model.isLoading && model.detailExecutions.isEmpty {
                    ProgressView()
                } else if model.detailExecutions.isEmpty {
                    Text("No se registraron ejercicios en esta sesión.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.detailExecutions) { execution in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.exerciseNameById[execution.exerciseId] ?? execution.exerciseId)
                                .font(.headline)
                            let sets = model.detailSetsByExecution[execution.id] ?? []
                            if sets.isEmpty {
                                Text("Sin series")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(sets.map { "\($0.reps) reps" }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Sesión")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if model.isLoading { ProgressView() } }
        .task { await model.loadSessionDetail(sessionId: sessionId) }
        .refreshable { await model.loadSessionDetail(sessionId: sessionId) }
    }
}

struct ActiveTrainingSessionView: View {
    @Bindable var model: ClientTrainingModel
    @State private var showAddExercise = false
    @State private var repsText: [String: String] = [:]
    @State private var vitalsRefresh = Date()

    private var watchMetrics: CompanionWorkoutMetrics? {
        _ = vitalsRefresh
        return WatchConnectivityBridge.shared.displayableWorkoutMetrics
    }

    var body: some View {
        List {
            if let snapshot = model.activeSession.snapshot {
                Section("Sesión") {
                    LabeledContent("Plan", value: snapshot.planName ?? "—")
                    LabeledContent("ID de sesión", value: snapshot.sessionId)
                    LabeledContent("Inicio", value: snapshot.startedAt.formatted(date: .abbreviated, time: .shortened))
                }
            } else {
                Section {
                    Text("Sin sesión activa")
                        .foregroundStyle(.secondary)
                }
            }

            if let metrics = watchMetrics {
                Section("Apple Watch") {
                    WatchVitalsStrip(metrics: metrics)
                }
            } else if model.activeSession.snapshot != nil {
                Section("Apple Watch") {
                    Text(
                        WatchConnectivityBridge.shared.isReachable
                            ? "Esperando el entrenamiento del Watch…"
                            : "Watch sin vincular"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if model.pendingOfflineCount > 0 {
                Section {
                    Text("\(model.pendingOfflineCount) acción(es) sin conexión pendientes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let status = model.status {
                Section { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
            if let error = model.lastError {
                Section { Text(error).font(.caption).foregroundStyle(.red) }
            }

            Section("Ejercicios") {
                if model.executions.isEmpty {
                    Text("Agregá un ejercicio para empezar a registrar series.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.executions) { execution in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.exerciseNameById[execution.exerciseId] ?? execution.exerciseId)
                            .font(.headline)
                        let sets = model.setsByExecution[execution.id] ?? []
                        if sets.isEmpty {
                            Text("Todavía no hay series")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(sets.map { "\($0.reps) reps" }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            TextField(
                                "Repeticiones",
                                text: Binding(
                                    get: { repsText[execution.id] ?? "10" },
                                    set: { repsText[execution.id] = $0 }
                                )
                            )
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 80)
                            Button("Registrar serie") {
                                let reps = Int(repsText[execution.id] ?? "10") ?? 10
                                Task { await model.logSet(executionId: execution.id, reps: reps) }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isWorking)
                            Button("Completar") {
                                Task { await model.completeExercise(executionId: execution.id) }
                            }
                            .disabled(model.isWorking)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Sesión activa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddExercise = true
                } label: {
                    Label("Agregar ejercicio", systemImage: "plus")
                }
                .disabled(model.activeSession.snapshot == nil || model.isWorking)
            }
        }
        .sheet(isPresented: $showAddExercise) {
            NavigationStack {
                List(model.exercises) { exercise in
                    Button {
                        showAddExercise = false
                        Task { await model.addExercise(exercise) }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                            if let description = exercise.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Agregar ejercicio")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showAddExercise = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .overlay { if model.isWorking || model.isLoading { ProgressView() } }
        .task { await model.loadActiveSession() }
        .refreshable { await model.loadActiveSession() }
        .task(id: model.network.isOnline) {
            await model.onNetworkTick()
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionWorkoutMetricsDidUpdate)) { _ in
            vitalsRefresh = Date()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            vitalsRefresh = Date()
        }
    }
}

private struct WatchVitalsStrip: View {
    let metrics: CompanionWorkoutMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bpm = metrics.heartRateBPM {
                LabeledContent("Frecuencia cardíaca", value: "\(Int(bpm.rounded())) bpm")
            }
            if let elapsed = metrics.elapsedSeconds {
                LabeledContent("Tiempo de entrenamiento", value: Self.formatElapsed(elapsed))
            }
            if let kcal = metrics.activeEnergyKilocalories {
                LabeledContent("Energía activa", value: "\(Int(kcal.rounded())) kcal")
            }
            if metrics.heartRateBPM == nil,
               metrics.elapsedSeconds == nil,
               metrics.activeEnergyKilocalories == nil
            {
                Text("Entrenamiento del Watch activo: todavía sin muestras")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
