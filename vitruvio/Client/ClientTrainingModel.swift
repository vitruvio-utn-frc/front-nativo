//
//  ClientTrainingModel.swift
//  vitruvio
//

import Foundation
import Observation
import VitruvioCore

@MainActor
@Observable
final class ClientTrainingModel {
    private(set) var plans: [TrainingPlanDTO] = []
    private(set) var planSessions: [TrainingSessionDTO] = []
    private(set) var executions: [ExerciseExecutionDTO] = []
    private(set) var setsByExecution: [String: [ExerciseSetDTO]] = [:]
    /// History detail (separate from active-session `executions` so browsing doesn't clobber logging).
    private(set) var detailSessionId: String?
    private(set) var detailExecutions: [ExerciseExecutionDTO] = []
    private(set) var detailSetsByExecution: [String: [ExerciseSetDTO]] = [:]
    private(set) var exercises: [ExerciseDTO] = []
    private(set) var isLoading = false
    private(set) var isWorking = false
    private(set) var lastError: String?
    private(set) var status: String?
    private(set) var pendingOfflineCount = 0

    let memberId: String
    let service: TrainingService
    let activeSession: ActiveTrainingSessionStore
    let offlineQueue: FileOfflineQueue
    let network: NetworkPathMonitor

    private var lastOnline = true
    nonisolated(unsafe) private var syncObserver: NSObjectProtocol?

    init(
        memberId: String,
        api: AuthenticatedAPIClient,
        activeSession: ActiveTrainingSessionStore? = nil,
        offlineQueue: FileOfflineQueue? = nil,
        network: NetworkPathMonitor? = nil
    ) {
        self.memberId = memberId
        self.service = TrainingService(api: api)
        let sessionStore = activeSession ?? ActiveTrainingSessionStore()
        let queue = offlineQueue ?? FileOfflineQueue()
        let pathMonitor = network ?? NetworkPathMonitor()
        self.activeSession = sessionStore
        self.offlineQueue = queue
        self.network = pathMonitor
        self.pendingOfflineCount = queue.pendingCount
        self.lastOnline = pathMonitor.isOnline
        syncObserver = NotificationCenter.default.addObserver(
            forName: .companionSyncDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.activeSession.reloadFromPersistence()
                if self.activeSession.activeSessionId != nil {
                    await self.loadActiveSession()
                } else {
                    self.executions = []
                    self.setsByExecution = [:]
                }
            }
        }
    }

    deinit {
        if let syncObserver {
            NotificationCenter.default.removeObserver(syncObserver)
        }
    }

    var exerciseNameById: [String: String] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
    }

    func onNetworkTick() async {
        let online = network.isOnline
        if online, (!lastOnline || offlineQueue.pendingCount > 0) {
            await flushOffline()
        }
        lastOnline = online
    }

    func loadPlans() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            plans = try await service.listPlans(forMemberId: memberId)
            if network.isOnline {
                await flushOffline()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadPlanDetail(planId: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            planSessions = try await service.listSessions(forPlanId: planId)
            if exercises.isEmpty {
                exercises = try await service.listExercises()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadSessionDetail(sessionId: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        detailSessionId = sessionId
        do {
            if exercises.isEmpty {
                exercises = try await service.listExercises()
            }
            _ = try? await service.getSession(id: sessionId)
            let listed = try await service.listExecutions(forSessionId: sessionId)
            var sets: [String: [ExerciseSetDTO]] = [:]
            for execution in listed {
                sets[execution.id] = try await service.listSets(forExecutionId: execution.id)
            }
            detailExecutions = listed
            detailSetsByExecution = sets
        } catch {
            lastError = error.localizedDescription
            detailExecutions = []
            detailSetsByExecution = [:]
        }
    }

    func isActiveSession(_ sessionId: String) -> Bool {
        activeSession.activeSessionId == sessionId
    }

    func startSession(plan: TrainingPlanDTO) async -> TrainingSessionDTO? {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        do {
            let session = try await service.createSession(planId: plan.id)
            activeSession.activate(
                sessionId: session.id,
                planId: plan.id,
                planName: plan.name
            )
            status = "Session started"
            executions = []
            setsByExecution = [:]
            Task {
                await CompanionPhoneGateway.shared.publish()
                await CompanionWatchWorkoutLauncher.openWatchForStrengthTraining()
            }
            return session
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func loadActiveSession() async {
        guard let sessionId = activeSession.activeSessionId else {
            executions = []
            setsByExecution = [:]
            return
        }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            if exercises.isEmpty {
                exercises = try await service.listExercises()
            }
            executions = try await service.listExecutions(forSessionId: sessionId)
            var sets: [String: [ExerciseSetDTO]] = [:]
            var totalSets = 0
            for execution in executions {
                let listed = try await service.listSets(forExecutionId: execution.id)
                sets[execution.id] = listed
                totalSets += listed.count
            }
            setsByExecution = sets
            activeSession.updateCounts(executionCount: executions.count, setCount: totalSets)
            pushCompanionTraining()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addExercise(_ exercise: ExerciseDTO) async {
        guard let sessionId = activeSession.activeSessionId else { return }
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        let request = CreateExerciseExecutionRequest(
            exerciseId: exercise.id,
            trainingSessionId: sessionId
        )
        do {
            if network.isOnline {
                _ = try await service.createExecution(request)
            } else {
                try offlineQueue.enqueueEncoded(.createExerciseExecution, value: request)
                pendingOfflineCount = offlineQueue.pendingCount
                status = "Queued exercise (offline)"
            }
            await loadActiveSession()
        } catch {
            if shouldQueue(error) {
                try? offlineQueue.enqueueEncoded(.createExerciseExecution, value: request)
                pendingOfflineCount = offlineQueue.pendingCount
                status = "Queued exercise (offline)"
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func logSet(executionId: String, reps: Int) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        let request = CreateExerciseSetRequest(exerciseExecutionId: executionId, reps: reps)
        do {
            if network.isOnline {
                _ = try await service.createSet(request)
                status = "Set logged"
            } else {
                try offlineQueue.enqueueEncoded(.createExerciseSet, value: request)
                pendingOfflineCount = offlineQueue.pendingCount
                status = "Queued set (offline)"
            }
            await loadActiveSession()
        } catch {
            if shouldQueue(error) {
                try? offlineQueue.enqueueEncoded(.createExerciseSet, value: request)
                pendingOfflineCount = offlineQueue.pendingCount
                status = "Queued set (offline)"
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func completeExercise(executionId: String, startedAt: Date = Date().addingTimeInterval(-300)) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        let request = CreateExerciseCompletionRequest(
            exerciseExecutionId: executionId,
            startDate: startedAt,
            endDate: Date(),
            caloriesBurnedInTotal: 0
        )
        do {
            if network.isOnline {
                _ = try await service.createCompletion(request)
                status = "Exercise completed"
            } else {
                try offlineQueue.enqueueEncoded(.createExerciseCompletion, value: request)
                pendingOfflineCount = offlineQueue.pendingCount
                status = "Queued completion (offline)"
            }
        } catch {
            if shouldQueue(error) {
                try? offlineQueue.enqueueEncoded(.createExerciseCompletion, value: request)
                pendingOfflineCount = offlineQueue.pendingCount
                status = "Queued completion (offline)"
            } else {
                lastError = error.localizedDescription
            }
        }
    }

    func endSession() {
        activeSession.clear()
        executions = []
        setsByExecution = [:]
        status = "Session cleared"
        pushCompanionTraining()
    }

    private func pushCompanionTraining() {
        Task { await CompanionPhoneGateway.shared.publish() }
    }

    private func flushOffline() async {
        let count = await offlineQueue.flush(using: service.api)
        pendingOfflineCount = offlineQueue.pendingCount
        if count > 0 {
            status = "Synced \(count) offline action(s)"
            if activeSession.activeSessionId != nil {
                await loadActiveSession()
            }
        }
    }

    private func shouldQueue(_ error: Error) -> Bool {
        if !network.isOnline { return true }
        if error is URLError { return true }
        if let apiError = error as? APIClientError {
            if case .unauthorized = apiError { return false }
            return true
        }
        return false
    }
}
