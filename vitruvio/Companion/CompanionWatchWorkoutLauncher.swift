//
//  CompanionWatchWorkoutLauncher.swift
//  vitruvio
//
//  Opens the Watch companion to start an HKWorkoutSession when training
//  begins on iPhone (supported HealthKit use case).
//

import Foundation
import HealthKit
import WatchConnectivity

enum CompanionWatchWorkoutLauncher {
    /// Launches the Watch app to handle the training workout (same activity type the Watch uses).
    /// Failures are non-fatal — training on iPhone continues either way.
    @MainActor
    static func openWatchForStrengthTraining() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        // Simulator often reports `isWatchAppInstalled == false` even while the
        // companion is running and reachable — still attempt the launch.
        guard session.isWatchAppInstalled || session.isReachable else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        do {
            try await HKHealthStore().startWatchApp(toHandle: configuration)
        } catch {
            // Watch may be locked, unpaired, or Health denied — ignore.
        }
    }
}
