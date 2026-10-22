//
//  WatchTrainingModel.swift
//  vitruvio.watch Watch App
//

import Foundation
import Observation
import VitruvioCore

/// Watch training UI — all API work is proxied to the iPhone companion.
@MainActor
@Observable
final class WatchTrainingModel {
    private(set) var plans: [CompanionPlanItem] = []
    private(set) var activeSession: ActiveTrainingSessionSnapshot?
    private(set) var isLoading = false
    private(set) var isWorking = false
    private(set) var lastError: String?
    private(set) var status: String?

    var healthKit: WatchHealthKitWorkoutManager { .shared }

    nonisolated(unsafe) private var syncObserver: NSObjectProtocol?

    init() {
        apply(WatchConnectivityBridge.shared.lastReceivedSnapshot)
        syncObserver = NotificationCenter.default.addObserver(
            forName: .companionSyncDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.apply(notification.object as? CompanionSyncSnapshot)
            }
        }
    }

    deinit {
        if let syncObserver {
            NotificationCenter.default.removeObserver(syncObserver)
        }
    }

    func refresh() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        if let snapshot = await WatchConnectivityBridge.shared.sendWatchAction("refresh") {
            apply(snapshot)
        } else {
            WatchConnectivityBridge.shared.requestFullSyncFromPhone()
            lastError = WatchConnectivityBridge.shared.lastError
        }
    }

    func continueActiveSession() async {
        guard let session = activeSession else { return }
        healthKit.companionTrainingSessionId = session.trainingSessionId
        startWorkoutInBackground()
        await refresh()
    }

    func startSession(plan: CompanionPlanItem, session: CompanionSessionItem) async -> Bool {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        guard let snapshot = await WatchConnectivityBridge.shared.sendWatchAction(
            "startSession",
            params: ["planId": plan.id, "trainingSessionId": session.id]
        ) else {
            lastError = WatchConnectivityBridge.shared.lastError ?? "iPhone no disponible"
            return false
        }
        apply(snapshot)
        if let active = activeSession {
            healthKit.companionTrainingSessionId = active.trainingSessionId
            startWorkoutInBackground()
            status = "Sesión iniciada"
            return true
        }
        lastError = snapshot.statusMessage ?? "No se pudo iniciar"
        return false
    }

    func markSet(executionId: String, index: Int, done: Bool) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        var params: [String: Any] = ["executionId": executionId, "index": index, "done": done]
        if let kcal = currentEnergy { params["energyKcal"] = kcal }
        if let snapshot = await WatchConnectivityBridge.shared.sendWatchAction("markSet", params: params) {
            apply(snapshot)
        } else {
            lastError = WatchConnectivityBridge.shared.lastError ?? "iPhone no disponible"
        }
    }

    func completeExercise(executionId: String) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        var params: [String: Any] = ["executionId": executionId]
        if let kcal = currentEnergy { params["energyKcal"] = kcal }
        if let snapshot = await WatchConnectivityBridge.shared.sendWatchAction("completeExercise", params: params) {
            apply(snapshot)
            status = "Ejercicio completado"
        } else {
            lastError = WatchConnectivityBridge.shared.lastError ?? "iPhone no disponible"
        }
    }

    /// Ends the run. Returns `false` when the iPhone could not be reached (the run is then still active).
    @discardableResult
    func endSession() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        // Pick up a server id that may have resolved since the last snapshot, so the workout can be linked.
        _ = await WatchConnectivityBridge.shared.sendWatchAction("refresh").map(apply)
        // HealthKit finishes in the background: the screen never waits on it.
        let completionId = activeSession?.completionServerId
        Task { await healthKit.endWorkout(completionServerId: completionId) }
        if let snapshot = await WatchConnectivityBridge.shared.sendWatchAction("endSession") {
            apply(snapshot)
            status = "Sesión finalizada"
            return activeSession == nil
        } else {
            lastError = WatchConnectivityBridge.shared.lastError ?? "iPhone no disponible"
            return false
        }
    }

    /// Training never waits on HealthKit: the permission prompt or the workout itself may take a while
    /// (or never answer), and logging must work without it.
    private func startWorkoutInBackground() {
        Task { await healthKit.startWorkoutIfAuthorized() }
    }

    /// Active energy of the running workout, only while one is actually collecting.
    private var currentEnergy: Double? {
        guard healthKit.isWorkoutActive, healthKit.totalEnergyBurnedKilocalories > 0 else { return nil }
        return healthKit.totalEnergyBurnedKilocalories
    }

    private func apply(_ snapshot: CompanionSyncSnapshot?) {
        guard let snapshot else { return }
        let previous = activeSession
        plans = snapshot.plans
        activeSession = snapshot.trainingSnapshot
        // The run was ended on the iPhone while this workout is still collecting: close it too.
        if previous != nil, activeSession == nil, healthKit.isWorkoutActive {
            let completionId = previous?.completionServerId
            Task { await healthKit.endWorkout(completionServerId: completionId) }
        }
        if let statusMessage = snapshot.statusMessage, !statusMessage.hasPrefix("ok:") {
            // Surface non-ok status from phone.
            if statusMessage.contains("sesión") || statusMessage.contains("error") {
                lastError = statusMessage
            } else {
                status = statusMessage
            }
        }
    }
}
