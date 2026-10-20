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
                                Text("\(snapshot.executionCount) ej. · \(snapshot.setCount) series")
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
                            Button {
                                Task {
                                    if await model.startSession(plan: plan) {
                                        path.append(WatchTrainingRoute.active)
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.name)
                                    Text("Iniciá desde el iPhone")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(model.isWorking || model.activeSession != nil)
                        }
                    }
                }
            }
            .navigationTitle("Entrenamiento")
            .navigationDestination(for: WatchTrainingRoute.self) { route in
                switch route {
                case .active:
                    WatchActiveSessionView(model: model)
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
}

struct WatchActiveSessionView: View {
    @Bindable var model: WatchTrainingModel
    @State private var repsByExecution: [String: Int] = [:]

    var body: some View {
        List {
            Section {
                if let snapshot = model.activeSession {
                    Text(snapshot.planName ?? "Entrenamiento")
                        .font(.headline)
                    Text("\(snapshot.executionCount) ej. · \(snapshot.setCount) series")
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
                if model.exercises.isEmpty {
                    Text("Agregá ejercicios desde el iPhone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.exercises) { execution in
                    executionRow(execution)
                }
            }

            Section {
                Button("Finalizar sesión", role: .destructive) {
                    Task { await model.endSession() }
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
    private func executionRow(_ execution: CompanionExerciseItem) -> some View {
        let reps = Binding(
            get: { repsByExecution[execution.id] ?? 10 },
            set: { repsByExecution[execution.id] = $0 }
        )

        VStack(alignment: .leading, spacing: 6) {
            Text(execution.name)
                .font(.caption)
                .fontWeight(.semibold)
            Text(
                execution.setReps.isEmpty
                    ? "Sin series"
                    : execution.setReps.map(String.init).joined(separator: "·")
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack {
                Button { reps.wrappedValue = max(1, reps.wrappedValue - 1) } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)

                Text("\(reps.wrappedValue)")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(minWidth: 24)

                Button { reps.wrappedValue = min(99, reps.wrappedValue + 1) } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            Button("Registrar serie") {
                Task { await model.logSet(executionId: execution.id, reps: reps.wrappedValue) }
            }
            .disabled(model.isWorking)

            Button("Listo") {
                Task { await model.completeExercise(executionId: execution.id) }
            }
            .disabled(model.isWorking)
        }
        .padding(.vertical, 2)
    }
}
