//
//  ClientTrainingModel.swift
//  vitruvio
//

import Foundation
import Observation
import VitruvioCore

/// One exercise of a finished run, joined with its prescription for display.
struct CompletedExerciseRow: Identifiable {
    let id: String
    let name: String
    let exercise: ExerciseDTO?
    let startDate: Date?
    let endDate: Date?
    let kcal: Double?
    /// Known only on the device that recorded the run.
    let source: CalorieSource?
}

struct CompletionDetail {
    let completion: TrainingSessionCompletionDTO
    let rows: [CompletedExerciseRow]

    var totalKcal: Double { rows.compactMap(\.kcal).reduce(0, +) }
}

/// Client training: follow a prescribed session, record what was done, browse past runs.
/// The prescription is read-only here; everything the client writes goes through `TrainingExecutionService`.
@MainActor
@Observable
final class ClientTrainingModel {
    private(set) var plans: [TrainingPlanDTO] = []
    private(set) var sessionsByPlan: [String: [PrescribedSession]] = [:]
    private(set) var historyByPlan: [String: [TrainingSessionCompletionDTO]] = [:]
    private(set) var exercises: [ExerciseDTO] = []
    private(set) var detail: CompletionDetail?
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var status: String?

    let memberId: String
    let service: TrainingService
    let execution: TrainingExecutionService
    let activeSession: ActiveTrainingSessionStore
    let network: NetworkPathMonitor

    private var lastOnline: Bool

    init(
        memberId: String,
        api: AuthenticatedAPIClient,
        activeSession: ActiveTrainingSessionStore? = nil,
        network: NetworkPathMonitor? = nil
    ) {
        self.memberId = memberId
        let training = TrainingService(api: api)
        self.service = training
        let store = activeSession ?? .shared
        self.activeSession = store
        self.execution = TrainingExecutionService(training: training, memberId: memberId, store: store)
        let pathMonitor = network ?? NetworkPathMonitor()
        self.network = pathMonitor
        self.lastOnline = pathMonitor.isOnline
    }

    var pendingOfflineCount: Int { execution.pendingCount }
    var discardedMessages: [String] { execution.discardedMessages }

    func exercise(id: String) -> ExerciseDTO? {
        exercises.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
    }

    /// The run in `completionId` is the one in progress on this device.
    func isActiveCompletion(_ completionId: String) -> Bool {
        activeSession.snapshot?.completionServerId?.caseInsensitiveCompare(completionId) == .orderedSame
    }

    func dismissDiscarded() {
        execution.dismissDiscarded()
    }

    func onNetworkTick() async {
        let online = network.isOnline
        if online, (!lastOnline || execution.pendingCount > 0) {
            let result = await execution.flush()
            if result.sent > 0 {
                status = "Se sincronizaron \(result.sent) registro(s) sin conexión"
            }
        }
        lastOnline = online
    }

    // MARK: Reads

    func loadPlans() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            plans = try await service.listPlans(forMemberId: memberId)
            if network.isOnline {
                await execution.flush()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Prescribed sessions and the client's own history for one plan.
    func loadPlanDetail(planId: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            async let sessionsTask = service.loadPrescribedSessions(planId: planId)
            async let historyTask = service.listCompletions(memberId: memberId, planId: planId)
            let (sessions, history) = try await (sessionsTask, historyTask)
            sessionsByPlan[planId] = sessions
            historyByPlan[planId] = history
            if exercises.isEmpty {
                exercises = try await service.listExercises()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadCompletionDetail(_ completion: TrainingSessionCompletionDTO) async {
        isLoading = true
        lastError = nil
        detail = nil
        defer { isLoading = false }
        do {
            if exercises.isEmpty {
                exercises = try await service.listExercises()
            }
            let completed = try await service.listExerciseCompletions(sessionCompletionId: completion.id)
            let executions = try await service.listExecutions(withIds: Set(completed.map(\.exerciseExecutionId)))
            let exerciseIdByExecution = Dictionary(
                executions.map { ($0.id.lowercased(), $0.exerciseId) },
                uniquingKeysWith: { first, _ in first }
            )
            let rows = completed.map { item -> CompletedExerciseRow in
                let exerciseId = exerciseIdByExecution[item.exerciseExecutionId.lowercased()]
                let exercise = exerciseId.flatMap(exercise(id:))
                return CompletedExerciseRow(
                    id: item.id,
                    name: exercise?.name ?? "Ejercicio",
                    exercise: exercise,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    kcal: item.caloriesBurnedInTotal,
                    source: CalorieSourceStore.source(forCompletionId: item.id)
                )
            }
            detail = CompletionDetail(completion: completion, rows: rows)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Active run

    func startSession(plan: TrainingPlanDTO, session: PrescribedSession) -> Bool {
        lastError = nil
        do {
            try execution.start(planId: plan.id, planName: plan.name, session: session)
            status = "Sesión iniciada"
            Task {
                await CompanionPhoneGateway.shared.publish()
                await CompanionWatchWorkoutLauncher.openWatchForStrengthTraining()
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func setSet(executionId: String, index: Int, done: Bool) {
        execution.setSet(
            executionId: executionId,
            index: index,
            done: done,
            energyKcal: execution.currentEnergyReading()
        )
        publishCompanion()
    }

    func completeExercise(executionId: String) {
        lastError = nil
        do {
            try execution.completeExercise(executionId: executionId, energyKcal: execution.currentEnergyReading())
            status = "Ejercicio completado"
        } catch {
            lastError = error.localizedDescription
        }
        publishCompanion()
    }

    func endSession() {
        lastError = nil
        do {
            try execution.end()
            status = "Sesión finalizada"
        } catch {
            lastError = error.localizedDescription
        }
        publishCompanion()
    }

    private func publishCompanion() {
        Task { await CompanionPhoneGateway.shared.publish() }
    }
}
