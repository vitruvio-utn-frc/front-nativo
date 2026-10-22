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
                            Text([snapshot.sessionLabel, "\(snapshot.completedExerciseCount) de \(snapshot.executionCount) ejercicios"]
                                .compactMap { $0 }
                                .joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Finalizar y guardar") {
                        model.endSession()
                    }
                }
            }

            TrainingSyncSections(model: model)

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
            case .completion(let id):
                if model.isActiveCompletion(id) {
                    ActiveTrainingSessionView(model: model)
                } else if let completion = model.historyByPlan.values.flatMap({ $0 }).first(where: { $0.id == id }) {
                    PastTrainingSessionView(model: model, completion: completion)
                } else {
                    Text("Sesión no encontrada")
                }
            }
        }
        .navigationDestination(isPresented: $showActiveSession) {
            ActiveTrainingSessionView(model: model)
        }
        .refreshable { await model.loadPlans() }
        .task(id: model.network.isOnline) {
            await model.onNetworkTick()
        }
    }
}

private enum TrainingRoute: Hashable {
    case plan(String)
    case completion(String)
}

/// Pending-sync notice, status line, errors and records the API rejected for good.
private struct TrainingSyncSections: View {
    @Bindable var model: ClientTrainingModel

    var body: some View {
        if model.pendingOfflineCount > 0 {
            Section {
                Text("\(model.pendingOfflineCount) registro(s) sin conexión pendientes de sincronizar")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        if !model.discardedMessages.isEmpty {
            Section {
                ForEach(Array(model.discardedMessages.enumerated()), id: \.offset) { _, message in
                    Text(message).font(.caption).foregroundStyle(.red)
                }
                Button("Entendido") { model.dismissDiscarded() }
            }
        }
        if let status = model.status {
            Section { Text(status).font(.caption).foregroundStyle(.secondary) }
        }
        if let error = model.lastError {
            Section { Text(error).font(.caption).foregroundStyle(.red) }
        }
    }
}

struct TrainingPlanDetailView: View {
    @Bindable var model: ClientTrainingModel
    let plan: TrainingPlanDTO
    var onStarted: () -> Void

    private var sessions: [PrescribedSession] { model.sessionsByPlan[plan.id] ?? [] }
    private var history: [TrainingSessionCompletionDTO] { model.historyByPlan[plan.id] ?? [] }
    private var hasActiveRun: Bool { model.activeSession.snapshot != nil }

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

            Section("Sesiones") {
                if sessions.isEmpty {
                    if !model.isLoading {
                        Text("Tu entrenador todavía no cargó sesiones en este plan.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.label).font(.headline)
                            Text(session.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Iniciar") {
                                if model.startSession(plan: plan, session: session) {
                                    onStarted()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(hasActiveRun)
                        }
                        .padding(.vertical, 2)
                    }
                    if hasActiveRun {
                        Text("Finalizá la sesión en curso antes de iniciar otra.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Historial") {
                if history.isEmpty {
                    Text("Todavía no entrenaste con este plan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history) { completion in
                        NavigationLink(value: TrainingRoute.completion(completion.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                if let start = completion.startDate {
                                    Text(start.formatted(date: .abbreviated, time: .shortened))
                                } else {
                                    Text("Sesión")
                                }
                                Text(model.isActiveCompletion(completion.id)
                                    ? "En curso"
                                    : (completion.duration.map(Self.durationLabel) ?? "Sin finalizar"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            TrainingSyncSections(model: model)
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if model.isLoading && sessions.isEmpty && history.isEmpty { ProgressView() } }
        .task { await model.loadPlanDetail(planId: plan.id) }
        .refreshable { await model.loadPlanDetail(planId: plan.id) }
    }

    static func durationLabel(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
}

/// Read-only detail of a finished run: what was done, when, and how many kcal.
struct PastTrainingSessionView: View {
    @Bindable var model: ClientTrainingModel
    let completion: TrainingSessionCompletionDTO

    var body: some View {
        List {
            Section("Sesión") {
                if let start = completion.startDate {
                    LabeledContent("Inicio", value: start.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent(
                    "Duración",
                    value: completion.duration.map(TrainingPlanDetailView.durationLabel) ?? "Sin finalizar"
                )
                if let detail = model.detail, detail.completion.id == completion.id {
                    LabeledContent("Calorías", value: kcalLabel(detail.totalKcal))
                }
            }
            if let error = model.lastError {
                Section { Text(error).font(.caption).foregroundStyle(.red) }
            }
            Section("Ejercicios completados") {
                if let detail = model.detail, detail.completion.id == completion.id {
                    if detail.rows.isEmpty {
                        Text("No se completó ningún ejercicio en esta sesión.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(detail.rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.name).font(.headline)
                            ExerciseVideoButton(exercise: row.exercise)
                            HStack {
                                if let start = row.startDate, let end = row.endDate {
                                    Text("\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                                }
                                Spacer()
                                if let kcal = row.kcal {
                                    Text(kcalLabel(kcal) + (row.source.map { " · \(sourceLabel($0))" } ?? ""))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } else if model.isLoading {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Sesión")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadCompletionDetail(completion) }
        .refreshable { await model.loadCompletionDetail(completion) }
    }
}

private func kcalLabel(_ kcal: Double) -> String {
    "\(kcal.formatted(.number.precision(.fractionLength(0)))) kcal"
}

private func sourceLabel(_ source: CalorieSource) -> String {
    switch source {
    case .healthkit: "medido"
    case .estimated: "estimado"
    }
}

struct ActiveTrainingSessionView: View {
    @Bindable var model: ClientTrainingModel
    @Environment(\.dismiss) private var dismiss
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
                    if let label = snapshot.sessionLabel {
                        LabeledContent("Sesión", value: label)
                    }
                    LabeledContent("Inicio", value: snapshot.startedAt.formatted(date: .abbreviated, time: .shortened))
                    if snapshot.totalKcal > 0 {
                        LabeledContent("Calorías", value: kcalLabel(snapshot.totalKcal))
                    }
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

            TrainingSyncSections(model: model)

            if let snapshot = model.activeSession.snapshot {
                ForEach(snapshot.exercises) { exercise in
                    Section {
                        ExerciseProgressRows(model: model, exercise: exercise)
                    }
                }
            }
        }
        .navigationTitle("Sesión activa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Finalizar") {
                    model.endSession()
                    dismiss()
                }
                .disabled(model.activeSession.snapshot == nil)
            }
        }
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

/// One prescribed exercise: tick its sets as they are done, then complete it.
private struct ExerciseProgressRows: View {
    @Bindable var model: ClientTrainingModel
    let exercise: ActiveExerciseProgress

    var body: some View {
        HStack {
            Text(exercise.name).font(.headline)
            Spacer()
            if exercise.isCompleted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        ExerciseVideoButton(exercise: model.exercise(id: exercise.exerciseId))
        ForEach(Array(exercise.prescribedReps.enumerated()), id: \.offset) { index, reps in
            Toggle(
                "Serie \(index + 1) · \(reps) reps",
                isOn: Binding(
                    get: { exercise.doneSetIndexes.contains(index) },
                    set: { model.setSet(executionId: exercise.id, index: index, done: $0) }
                )
            )
            .disabled(exercise.isCompleted)
        }
        if exercise.isCompleted {
            if let kcal = exercise.kcal {
                LabeledContent(
                    "Calorías",
                    value: kcalLabel(kcal) + (exercise.kcalSource.map { " · \(sourceLabel($0))" } ?? "")
                )
                .font(.caption)
            }
        } else {
            Button("Completar ejercicio") {
                model.completeExercise(executionId: exercise.id)
            }
            .buttonStyle(.borderedProminent)
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
