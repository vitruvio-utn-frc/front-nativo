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
    private let activeSession = ActiveTrainingSessionStore.shared
    private var cachedPlans: [CompanionPlanItem] = []
    private var prescribedByPlan: [String: [PrescribedSession]] = [:]
    private var cachedExecution: TrainingExecutionService?
    private var executionMemberId: String?

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
            let payload = WatchConnectivityBridge.encodeContext(quick)
            WatchConnectivityBridge.shared.pushSnapshot(quick, event: .reloadRequest)
            Task {
                await self.refreshPlansIfNeeded()
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
                guard let planId = message["planId"] as? String,
                      let sessionId = message["trainingSessionId"] as? String
                else {
                    return ["ok": false, "error": "missing_startSession_params"]
                }
                try await startSession(planId: planId, trainingSessionId: sessionId)
            case "markSet":
                guard let executionId = message["executionId"] as? String,
                      let index = Self.intValue(message["index"]),
                      let done = (message["done"] as? Bool) ?? (message["done"] as? NSNumber)?.boolValue
                else {
                    return ["ok": false, "error": "missing_markSet_params"]
                }
                let execution = try executionService()
                execution.setSet(
                    executionId: executionId,
                    index: index,
                    done: done,
                    energyKcal: Self.doubleValue(message["energyKcal"]) ?? execution.currentEnergyReading()
                )
            case "completeExercise":
                guard let executionId = message["executionId"] as? String else {
                    return ["ok": false, "error": "missing_executionId"]
                }
                let execution = try executionService()
                try execution.completeExercise(
                    executionId: executionId,
                    energyKcal: Self.doubleValue(message["energyKcal"]) ?? execution.currentEnergyReading()
                )
            case "endSession":
                try executionService().end()
            case "refresh":
                await refreshPlansIfNeeded()
            default:
                return ["ok": false, "error": "unknown_action"]
            }
            let snap = buildLocalSnapshot(statusMessage: "ok:\(action)")
            WatchConnectivityBridge.shared.pushSnapshot(snap, event: .trainingSessionChanged)
            return WatchConnectivityBridge.encodeContext(snap)
        } catch {
            let snap = buildLocalSnapshot(statusMessage: error.localizedDescription)
            WatchConnectivityBridge.shared.pushSnapshot(snap, event: .reloadRequest)
            return WatchConnectivityBridge.encodeContext(snap)
        }
    }

    /// Local-only snapshot — safe for WCSession reply handlers (no network).
    private func buildLocalSnapshot(statusMessage: String? = nil) -> CompanionSyncSnapshot {
        let hasAuth = resolveHasAuth()
        if !hasAuth {
            cachedPlans = []
            prescribedByPlan = [:]
        }
        return CompanionSyncSnapshot.phoneUIState(
            hasAuth: hasAuth,
            training: activeSession.snapshot,
            plans: cachedPlans,
            statusMessage: statusMessage
        )
    }

    private func resolveHasAuth() -> Bool {
        if auth?.isAuthenticated == true { return true }
        // Fallback if UI state lags Keychain after restore.
        if (try? KeychainTokenStore().load()) != nil { return true }
        return false
    }

    /// Plans are matched on the `User` id of the active gym context, not the Keycloak `sub`.
    private func memberId() throws -> String {
        guard resolveHasAuth(), let userId = SharedGymContextReader.load()?.userId else {
            throw CompanionGatewayError.notAuthenticated
        }
        return userId
    }

    private func executionService() throws -> TrainingExecutionService {
        let userId = try memberId()
        guard let auth else { throw CompanionGatewayError.notAuthenticated }
        if let cachedExecution, executionMemberId == userId { return cachedExecution }
        let created = TrainingExecutionService(training: TrainingService(api: auth.apiClient), memberId: userId)
        cachedExecution = created
        executionMemberId = userId
        return created
    }

    private func refreshPlansIfNeeded() async {
        do {
            let training = try executionService().training
            let plans = try await training.listPlans(forMemberId: try memberId())
            let sessions = try await training.loadPrescribedSessions(planIds: plans.map(\.id))
            prescribedByPlan = sessions
            cachedPlans = plans.map { plan in
                CompanionPlanItem(
                    id: plan.id,
                    name: plan.name,
                    sessions: (sessions[plan.id] ?? []).map(CompanionSessionItem.init)
                )
            }
        } catch {
            log.error("refreshPlans failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startSession(planId: String, trainingSessionId: String) async throws {
        if prescribedByPlan[planId] == nil { await refreshPlansIfNeeded() }
        guard let session = prescribedByPlan[planId]?.first(where: { $0.id == trainingSessionId }) else {
            throw CompanionGatewayError.sessionUnavailable
        }
        let planName = cachedPlans.first(where: { $0.id == planId })?.name
        try executionService().start(planId: planId, planName: planName, session: session)
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let value = any as? Int { return value }
        return (any as? NSNumber)?.intValue
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let value = any as? Double { return value }
        return (any as? NSNumber)?.doubleValue
    }
}

private enum CompanionGatewayError: LocalizedError {
    case notAuthenticated
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Iniciá sesión en el iPhone"
        case .sessionUnavailable: "No se encontró la sesión del plan: actualizá desde el iPhone"
        }
    }
}
