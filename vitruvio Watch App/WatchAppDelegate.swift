//
//  WatchAppDelegate.swift
//  vitruvio.watch Watch App
//

import HealthKit
import WatchKit
import WatchConnectivity
import VitruvioCore

/// Completes Watch Connectivity background wakes so the process is not SIGKILL'd.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    private var wcBackgroundTasks: [WKWatchConnectivityRefreshBackgroundTask] = []
    private var activationObs: NSKeyValueObservation?
    private var pendingObs: NSKeyValueObservation?

    func applicationDidFinishLaunching() {
        WatchConnectivityBridge.shared.activate()
        // A workout left alive by a terminated run would block closing the next one.
        Task { @MainActor in await WatchHealthKitWorkoutManager.shared.recoverActiveWorkout() }

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        activationObs = session.observe(\.activationState, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.completeWCTasksIfSettled() }
        }
        pendingObs = session.observe(\.hasContentPending, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.completeWCTasksIfSettled() }
        }
    }

    /// iPhone called `HKHealthStore.startWatchApp(toHandle:)` when training started.
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            WatchConnectivityBridge.shared.requestFullSyncFromPhone()
            if let sessionId = WatchConnectivityBridge.shared.lastReceivedSnapshot?.trainingSessionId {
                WatchHealthKitWorkoutManager.shared.companionTrainingSessionId = sessionId
            }
            await WatchHealthKitWorkoutManager.shared.startWorkoutIfAuthorized(
                configuration: workoutConfiguration
            )
        }
    }

    /// The system relaunched the app because a workout was still running when it was terminated.
    func handleActiveWorkoutRecovery() {
        Task { @MainActor in
            await WatchHealthKitWorkoutManager.shared.recoverActiveWorkout()
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let wcTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                wcBackgroundTasks.append(wcTask)
                completeWCTasksIfSettled()
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    @MainActor
    private func completeWCTasksIfSettled() {
        guard WCSession.isSupported() else {
            finishAllWCTasks()
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated, !session.hasContentPending else { return }
        finishAllWCTasks()
    }

    @MainActor
    private func finishAllWCTasks() {
        wcBackgroundTasks.forEach { $0.setTaskCompletedWithSnapshot(false) }
        wcBackgroundTasks.removeAll()
    }
}
