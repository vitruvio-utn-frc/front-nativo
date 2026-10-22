//
//  WatchTrainingViews.swift
//  vitruvio.watch Watch App
//

import SwiftUI
import VitruvioCore

struct WatchTrainingRootView: View {
    @State private var model = WatchTrainingModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Label(
                        WatchConnectivityBridge.shared.isReachable ? "iPhone vinculado" : "Abrí la app en el iPhone",
                        systemImage: WatchConnectivityBridge.shared.isReachable
                            ? "iphone.gen3.radiowaves.left.and.right"
                            : "iphone"
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        WatchConnectivityBridge.shared.isReachable ? .green : .secondary
                    )
                }

                if let snapshot = model.activeSession {
                    Section("Activa") {
                        Button {
                            path.append(WatchTrainingRoute.active)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snapshot.planName ?? "Entrenamiento")
                                    .font(.headline)
                                Text("\(snapshot.completedExerciseCount) de \(snapshot.executionCount) ejercicios")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let status = model.status {
                    Section { Text(status).font(.caption2).foregroundStyle(.secondary) }
                }
                if let error = model.lastError {
                    Section { Text(error).font(.caption2).foregroundStyle(.red) }
                }

                Section("Planes") {
                    if model.isLoading && model.plans.isEmpty {
                        ProgressView()
                    } else if model.plans.isEmpty {
                        Text("Sin planes en el iPhone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.plans) { plan in
                            NavigationLink(value: WatchTrainingRoute.plan(plan.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.name)
                                    Text(plan.sessions.isEmpty ? "Sin sesiones" : "\(plan.sessions.count) sesiones")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(model.activeSession != nil)
                        }
                    }
                }
            }
            .navigationTitle("Entrenamiento")
            .navigationDestination(for: WatchTrainingRoute.self) { route in
                switch route {
                case .active:
                    WatchActiveSessionView(model: model)
                case .plan(let id):
                    if let plan = model.plans.first(where: { $0.id == id }) {
                        WatchPlanSessionsView(model: model, plan: plan) {
                            path = NavigationPath()
                            path.append(WatchTrainingRoute.active)
                        }
                    } else {
                        Text("Plan no encontrado")
                    }
                }
            }
            .overlay { if model.isWorking { ProgressView() } }
            .task {
                await model.refresh()
                if model.activeSession != nil {
                    await model.continueActiveSession()
                }
            }
        }
    }
}

private enum WatchTrainingRoute: Hashable {
    case active
    case plan(String)
}

/// Prescribed sessions of a plan: pick one to start following it.
private struct WatchPlanSessionsView: View {
    @Bindable var model: WatchTrainingModel
    let plan: CompanionPlanItem
    var onStarted: () -> Void

    var body: some View {
        List {
            if plan.sessions.isEmpty {
                Text("Tu entrenador todavía no cargó sesiones")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ForEach(plan.sessions) { session in
                Button {
                    Task {
                        if await model.startSession(plan: plan, session: session) {
                            onStarted()
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.label).font(.headline)
                        Text(session.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .disabled(model.isWorking || model.activeSession != nil)
            }
            if let error = model.lastError {
                Text(error).font(.caption2).foregroundStyle(.red)
            }
        }
        .navigationTitle(plan.name)
        .overlay { if model.isWorking { ProgressView() } }
    }
}

struct WatchActiveSessionView: View {
    @Bindable var model: WatchTrainingModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                if let snapshot = model.activeSession {
                    Text(snapshot.planName ?? "Entrenamiento")
                        .font(.headline)
                    Text([snapshot.sessionLabel, "\(snapshot.completedExerciseCount) de \(snapshot.executionCount) ej."]
                        .compactMap { $0 }
                        .joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                heartRateRow
            }

            if let status = model.status {
                Section { Text(status).font(.caption2).foregroundStyle(.secondary) }
            }
            if let error = model.lastError {
                Section { Text(error).font(.caption2).foregroundStyle(.red) }
            }

            Section("Ejercicios") {
                if let exercises = model.activeSession?.exercises, !exercises.isEmpty {
                    ForEach(exercises) { exercise in
                        exerciseRow(exercise)
                    }
                } else {
                    Text("Sin ejercicios en esta sesión")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            let instructions = (model.activeSession?.exercises ?? []).compactMap { exercise in
                ExerciseMediaLink(exercise.videoUrl).map { (exercise, $0) }
            }
            if !instructions.isEmpty {
                Section("Instrucciones") {
                    ForEach(instructions, id: \.0.id) { exercise, link in
                        NavigationLink {
                            WatchExerciseInstructionsView(name: exercise.name, link: link)
                        } label: {
                            Label(exercise.name, systemImage: "play.circle")
                                .font(.caption)
                        }
                    }
                }
            }

            Section {
                Button("Finalizar sesión") {
                    Task {
                        // Back to the previous screen once the run is over; stay to show the error otherwise.
                        if await model.endSession() { dismiss() }
                    }
                }
                .disabled(model.isWorking)
            }
        }
        .navigationTitle("Sesión")
        .overlay { if model.isWorking || model.isLoading { ProgressView() } }
        .task { await model.continueActiveSession() }
    }

    @ViewBuilder
    private var heartRateRow: some View {
        if let bpm = model.healthKit.heartRateBPM {
            Label("\(Int(bpm)) bpm", systemImage: "heart.fill")
                .font(.caption)
                .foregroundStyle(.red)
        } else if let reason = model.healthKit.hrUnavailableReason {
            Text(reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text("HR…")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: ActiveExerciseProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                if exercise.isCompleted {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }

            ForEach(Array(exercise.prescribedReps.enumerated()), id: \.offset) { index, reps in
                Toggle(
                    "Serie \(index + 1) · \(reps)",
                    isOn: Binding(
                        get: { exercise.doneSetIndexes.contains(index) },
                        set: { done in
                            Task { await model.markSet(executionId: exercise.id, index: index, done: done) }
                        }
                    )
                )
                .font(.caption2)
                .disabled(exercise.isCompleted || model.isWorking)
            }

            if exercise.isCompleted {
                if let kcal = exercise.kcal {
                    Text("\(kcal.formatted(.number.precision(.fractionLength(0)))) kcal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Listo") {
                    Task { await model.completeExercise(executionId: exercise.id) }
                }
                .disabled(model.isWorking)
            }
        }
        .padding(.vertical, 2)
    }
}
