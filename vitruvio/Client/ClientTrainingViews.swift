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
                ProgressView("Loading training…")
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
        }
    }

    @ViewBuilder
    private func plansList(_ model: ClientTrainingModel) -> some View {
        List {
            if let snapshot = model.activeSession.snapshot {
                Section("Active session") {
                    Button {
                        showActiveSession = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.planName ?? "Workout")
                            Text("\(snapshot.executionCount) exercises · \(snapshot.setCount) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("End session", role: .destructive) {
                        model.endSession()
                    }
                }
            }

            if model.pendingOfflineCount > 0 {
                Section {
                    Text("\(model.pendingOfflineCount) offline action(s) pending sync")
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

            Section("My plans") {
                if model.isLoading && model.plans.isEmpty {
                    ProgressView()
                } else if model.plans.isEmpty {
                    ContentUnavailableView(
                        "No training plans",
                        systemImage: "list.clipboard",
                        description: Text("When a trainer assigns a plan, it will show up here.")
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
                    Text("Plan not found")
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
}

struct TrainingPlanDetailView: View {
    @Bindable var model: ClientTrainingModel
    let plan: TrainingPlanDTO
    var onStarted: () -> Void

    var body: some View {
        List {
            Section("Plan") {
                LabeledContent("Name", value: plan.name)
                if let description = plan.description, !description.isEmpty {
                    Text(description)
                }
                if !plan.durationLabel.isEmpty {
                    LabeledContent("Duration", value: plan.durationLabel)
                }
            }

            Section("Sessions on this plan") {
                if model.planSessions.isEmpty {
                    Text("No prior sessions — start one to begin logging.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.planSessions) { session in
                        Text(session.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                Button("Start") {
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

struct ActiveTrainingSessionView: View {
    @Bindable var model: ClientTrainingModel
    @State private var showAddExercise = false
    @State private var repsText: [String: String] = [:]

    var body: some View {
        List {
            if let snapshot = model.activeSession.snapshot {
                Section("Session") {
                    LabeledContent("Plan", value: snapshot.planName ?? "—")
                    LabeledContent("Session id", value: snapshot.sessionId)
                    LabeledContent("Started", value: snapshot.startedAt.formatted(date: .abbreviated, time: .shortened))
                }
            } else {
                Section {
                    Text("No active session")
                        .foregroundStyle(.secondary)
                }
            }

            if model.pendingOfflineCount > 0 {
                Section {
                    Text("\(model.pendingOfflineCount) offline action(s) pending")
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

            Section("Exercises") {
                if model.executions.isEmpty {
                    Text("Add an exercise to start logging sets.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.executions) { execution in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.exerciseNameById[execution.exerciseId] ?? execution.exerciseId)
                            .font(.headline)
                        let sets = model.setsByExecution[execution.id] ?? []
                        if sets.isEmpty {
                            Text("No sets yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(sets.map { "\($0.reps) reps" }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            TextField(
                                "Reps",
                                text: Binding(
                                    get: { repsText[execution.id] ?? "10" },
                                    set: { repsText[execution.id] = $0 }
                                )
                            )
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 80)
                            Button("Log set") {
                                let reps = Int(repsText[execution.id] ?? "10") ?? 10
                                Task { await model.logSet(executionId: execution.id, reps: reps) }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isWorking)
                            Button("Complete") {
                                Task { await model.completeExercise(executionId: execution.id) }
                            }
                            .disabled(model.isWorking)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Active session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddExercise = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
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
                .navigationTitle("Add exercise")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddExercise = false }
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
    }
}
