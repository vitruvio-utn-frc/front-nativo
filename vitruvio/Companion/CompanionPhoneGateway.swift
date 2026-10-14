//
//  CompanionPhoneGateway.swift
//  vitruvio
//
//  iPhone owns auth + API. Watch only receives UI snapshots and sends actions.
//

import Foundation
import OSLog
import VitruvioCore

@MainActor
final class CompanionPhoneGateway {
    static let shared = CompanionPhoneGateway()

    private let log = Logger(subsystem: "com.santiago-alvarado.vitruvio", category: "CompanionPhone")

    private weak var auth: AuthSessionModel?
    private let activeSession = ActiveTrainingSessionStore()
    private var cachedPlans: [CompanionPlanItem] = []
    private var cachedExercises: [CompanionExerciseItem] = []

    private init() {}

    func start(auth: AuthSessionModel) {
        self.auth = auth
        WatchConnectivityBridge.shared.phoneMessageHandler = { [weak self] message in
            guard let self else {
                return ["ok": false, "error": "gateway_unavailable"]
            }
            return await self.handle(message)
        }
        Task { await publish() }
    }

    func publish(statusMessage: String? = nil) async {
        // Never block the Watch reply path on network — push local auth/session first.
        let quick = buildLocalSnapshot(statusMessage: statusMessage)
        log.info("publish hasAuth=\(quick.hasAuth, privacy: .public) role=\(quick.roleId ?? "-", privacy: .public) plans=\(self.cachedPlans.count)")
        WatchConnectivityBridge.shared.pushSnapshot(quick, event: .reloadRequest)

        if quick.hasAuth {
            Task {
                await self.refreshPlansIfNeeded()
                if self.activeSession.activeSessionId != nil {
                    try? await self.refreshActiveDetails()
                }
                let rich = self.buildLocalSnapshot(statusMessage: statusMessage)
                WatchConnectivityBridge.shared.pushSnapshot(rich, event: .reloadRequest)
            }
        }
    }

    private func handle(_ message: [String: Any]) async -> [String: Any] {
        if let request = message["request"] as? String, request == "fullSync" {
            // Instant local snapshot + applicationContext only (no nested sendMessage).
            let quick = buildLocalSnapshot()
            log.info("fullSync hasAuth=\(quick.hasAuth, privacy: .public)")
            let payload = ManualEncoder.encode(quick)
            WatchConnectivityBridge.shared.pushSnapshot(quick, event: .reloadRequest)
            Task {
                await self.refreshPlansIfNeeded()
                if self.activeSession.activeSessionId != nil {
                    try? await self.refreshActiveDetails()
                }
                let rich = self.buildLocalSnapshot()
                WatchConnectivityBridge.shared.pushSnapshot(rich, event: .reloadRequest)
            }
            return payload
        }

        guard let action = message["action"] as? String else {
            return ["ok": false, "error": "unknown_message"]
        }

        do {
            switch action {
            case "startSession":
                guard let planId = message["planId"] as? String else {
                    return ["ok": false, "error": "missing_planId"]
                }
                try await startSession(planId: planId)
            case "logSet":
                guard let executionId = message["executionId"] as? String else {
                    return ["ok": false, "error": "missing_executionId"]
                }
                let reps = (message["reps"] as? Int)
                    ?? (message["reps"] as? NSNumber)?.intValue
                    ?? 0
                guard reps > 0 else {
                    return ["ok": false, "error": "missing_logSet_params"]
                }
                try await logSet(executionId: executionId, reps: reps)
            case "completeExercise":
                guard let executionId = message["executionId"] as? String else {
                    return ["ok": false, "error": "missing_executionId"]
                }
                try await completeExercise(executionId: executionId)
            case "endSession":
                activeSession.clear()
                cachedExercises = []
            case "refresh":
                try await refreshActiveDetails()
                await refreshPlansIfNeeded()
            default:
                return ["ok": false, "error": "unknown_action"]
            }
            let snap = buildLocalSnapshot(statusMessage: "ok:\(action)")
            WatchConnectivityBridge.shared.pushSnapshot(snap, event: .trainingSessionChanged)
            return ManualEncoder.encode(snap)
        } catch {
            let snap = buildLocalSnapshot(statusMessage: error.localizedDescription)
            WatchConnectivityBridge.shared.pushSnapshot(snap, event: .reloadRequest)
            return ManualEncoder.encode(snap)
        }
    }

    /// Local-only snapshot — safe for WCSession reply handlers (no network).
    private func buildLocalSnapshot(statusMessage: String? = nil) -> CompanionSyncSnapshot {
        activeSession.reloadFromPersistence()
        let hasAuth = resolveHasAuth()
        if !hasAuth {
            cachedPlans = []
            cachedExercises = []
        }
        return CompanionSyncSnapshot.phoneUIState(
            hasAuth: hasAuth,
            training: activeSession.snapshot,
            plans: cachedPlans,
            exercises: cachedExercises,
            statusMessage: statusMessage
        )
    }

    private func resolveHasAuth() -> Bool {
        if auth?.isAuthenticated == true { return true }
        // Fallback if UI state lags Keychain after restore.
        if (try? KeychainTokenStore().load()) != nil { return true }
        return false
    }

    private func service() throws -> (TrainingService, String) {
        guard let auth, let userId = auth.subject ?? (try? KeychainTokenStore().load())?.subject else {
            throw CompanionGatewayError.notAuthenticated
        }
        guard resolveHasAuth() else {
            throw CompanionGatewayError.notAuthenticated
        }
        return (TrainingService(api: auth.apiClient), userId)
    }

    private func refreshPlansIfNeeded() async {
        do {
            let (service, userId) = try service()
            let plans = try await service.listPlans(forMemberId: userId)
            cachedPlans = plans.map { CompanionPlanItem(id: $0.id, name: $0.name) }
        } catch {
            log.error("refreshPlans failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startSession(planId: String) async throws {
        let (service, _) = try service()
        let planName = cachedPlans.first(where: { $0.id == planId })?.name
        let session = try await service.createSession(planId: planId)
        activeSession.activate(sessionId: session.id, planId: planId, planName: planName)
        try await refreshActiveDetails()
    }

    private func refreshActiveDetails() async throws {
        guard let sessionId = activeSession.activeSessionId else {
            cachedExercises = []
            return
        }
        let (service, _) = try service()
        let exercises = try await service.listExercises()
        let nameById = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
        let executions = try await service.listExecutions(forSessionId: sessionId)
        var rows: [CompanionExerciseItem] = []
        var totalSets = 0
        for execution in executions {
            let sets = try await service.listSets(forExecutionId: execution.id)
            totalSets += sets.count
            rows.append(
                CompanionExerciseItem(
                    id: execution.id,
                    exerciseId: execution.exerciseId,
                    name: nameById[execution.exerciseId] ?? execution.exerciseId,
                    setReps: sets.map(\.reps)
                )
            )
        }
        cachedExercises = rows
        activeSession.updateCounts(executionCount: executions.count, setCount: totalSets)
    }

    private func logSet(executionId: String, reps: Int) async throws {
        let (service, _) = try service()
        _ = try await service.createSet(
            CreateExerciseSetRequest(exerciseExecutionId: executionId, reps: reps)
        )
        try await refreshActiveDetails()
    }

    private func completeExercise(executionId: String) async throws {
        let (service, _) = try service()
        _ = try await service.createCompletion(
            CreateExerciseCompletionRequest(
                exerciseExecutionId: executionId,
                startDate: Date().addingTimeInterval(-300),
                endDate: Date(),
                caloriesBurnedInTotal: 0
            )
        )
        try await refreshActiveDetails()
    }

}

private enum CompanionGatewayError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Sign in on iPhone"
        }
    }
}

private enum ManualEncoder {
    private static let listEncoder = JSONEncoder()

    static func encode(_ snapshot: CompanionSyncSnapshot) -> [String: Any] {
        var dict: [String: Any] = [
            "v": 3,
            "event": CompanionSyncEvent.reloadRequest.rawValue,
            "source": snapshot.source.rawValue,
            "updatedAt": snapshot.updatedAt.timeIntervalSince1970,
            "hasAuth": snapshot.hasAuth,
            "trainingExecutionCount": snapshot.trainingExecutionCount,
            "trainingSetCount": snapshot.trainingSetCount,
        ]
        if let userId = snapshot.userId { dict["userId"] = userId }
        if let gymId = snapshot.gymId { dict["gymId"] = gymId }
        if let roleId = snapshot.roleId { dict["roleId"] = roleId }
        if let shell = snapshot.shell { dict["shell"] = shell }
        if let trainingSessionId = snapshot.trainingSessionId {
            dict["trainingSessionId"] = trainingSessionId
        }
        if let trainingPlanId = snapshot.trainingPlanId {
            dict["trainingPlanId"] = trainingPlanId
        }
        if let trainingPlanName = snapshot.trainingPlanName {
            dict["trainingPlanName"] = trainingPlanName
        }
        if let trainingStartedAt = snapshot.trainingStartedAt {
            dict["trainingStartedAt"] = trainingStartedAt.timeIntervalSince1970
        }
        if let statusMessage = snapshot.statusMessage {
            dict["statusMessage"] = statusMessage
        }
        if let data = try? listEncoder.encode(snapshot.plans),
           let json = String(data: data, encoding: .utf8)
        {
            dict["plansJSON"] = json
        }
        if let data = try? listEncoder.encode(snapshot.exercises),
           let json = String(data: data, encoding: .utf8)
        {
            dict["exercisesJSON"] = json
        }
        return dict
    }
}
