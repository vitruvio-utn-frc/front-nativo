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
    private(set) var exercises: [CompanionExerciseItem] = []
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
        healthKit.companionTrainingSessionId = session.sessionId
        await healthKit.startWorkoutIfAuthorized()
        await refresh()
    }

    func startSession(plan: CompanionPlanItem) async -> Bool {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        guard let snapshot = await WatchConnectivityBridge.shared.sendWatchAction(
            "startSession",
            params: ["planId": plan.id]
        ) else {
            lastError = WatchConnectivityBridge.shared.lastError ?? "iPhone unavailable"
            return false
        }
        apply(snapshot)
        if let session = activeSession {
            healthKit.companionTrainingSessionId = session.sessionId
            await healthKit.startWorkoutIfAuthorized()
            status = "Session started"
            return true
        }
        lastError = snapshot.statusMessage ?? "Could not start"
        return false
    }

    func logSet(executionId: String, reps: Int) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        if let snapshot = await WatchConnectivityBridge.shared.sendWatchAction(
            "logSet",
            params: ["executionId": executionId, "reps": reps]
        ) {
            apply(snapshot)
            status = "Set logged"
        } else {
            lastError = WatchConnectivityBridge.shared.lastError ?? "iPhone unavailable"
        }
    }

    func completeExercise(executionId: String) async {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        if let snapshot = await WatchConnectivityBridge.shared.sendWatchAction(
            "completeExercise",
            params: ["executionId": executionId]
        ) {
            apply(snapshot)
            status = "Exercise done"
        } else {
            lastError = WatchConnectivityBridge.shared.lastError ?? "iPhone unavailable"
        }
    }

    func endSession() async {
        isWorking = true
        defer { isWorking = false }
        _ = await healthKit.endWorkout()
        if let snapshot = await WatchConnectivityBridge.shared.sendWatchAction("endSession") {
            apply(snapshot)
            status = "Session ended"
        } else {
            lastError = WatchConnectivityBridge.shared.lastError ?? "iPhone unavailable"
        }
    }

    private func apply(_ snapshot: CompanionSyncSnapshot?) {
        guard let snapshot else { return }
        plans = snapshot.plans
        exercises = snapshot.exercises
        activeSession = snapshot.trainingSnapshot
        if let statusMessage = snapshot.statusMessage, !statusMessage.hasPrefix("ok:") {
            // Surface non-ok status from phone.
            if statusMessage.contains("Sign in") || statusMessage.contains("error") {
                lastError = statusMessage
            } else {
                status = statusMessage
            }
        }
    }
}
