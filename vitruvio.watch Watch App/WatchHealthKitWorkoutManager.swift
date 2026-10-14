//
//  WatchHealthKitWorkoutManager.swift
//  vitruvio.watch Watch App
//

import Foundation
import HealthKit
import Observation

/// Runs a Watch strength `HKWorkoutSession` and surfaces live heart rate.
@MainActor
@Observable
final class WatchHealthKitWorkoutManager: NSObject {
    static let shared = WatchHealthKitWorkoutManager()

    enum AuthorizationState: Equatable {
        case notDetermined
        case authorized
        case denied
        case unavailable
    }

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private(set) var authorizationState: AuthorizationState = .notDetermined
    private(set) var isWorkoutActive = false
    private(set) var heartRateBPM: Double?
    private(set) var totalEnergyBurnedKilocalories: Double = 0
    private(set) var hrUnavailableReason: String?
    private(set) var workoutStartedAt: Date?

    var canShowHeartRate: Bool {
        authorizationState == .authorized && hrUnavailableReason == nil
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            hrUnavailableReason = "Health unavailable"
            return
        }

        guard let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else {
            authorizationState = .unavailable
            hrUnavailableReason = "Health unavailable"
            return
        }

        let toShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            heartRate,
            energy,
        ]

        do {
            try await healthStore.requestAuthorization(toShare: toShare, read: toRead)
            let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
            if status == .sharingDenied {
                authorizationState = .denied
                hrUnavailableReason = "HR unavailable"
            } else {
                authorizationState = .authorized
                hrUnavailableReason = nil
            }
        } catch {
            authorizationState = .denied
            hrUnavailableReason = "HR unavailable"
        }
    }

    /// Starts a traditional strength workout. No-ops gracefully when auth is denied.
    func startWorkoutIfAuthorized(configuration: HKWorkoutConfiguration? = nil) async {
        await requestAuthorization()
        guard authorizationState == .authorized else { return }
        guard session == nil else { return }

        let configuration = configuration ?? {
            let config = HKWorkoutConfiguration()
            config.activityType = .traditionalStrengthTraining
            config.locationType = .indoor
            return config
        }()

        do {
            let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let workoutBuilder = workoutSession.associatedWorkoutBuilder()
            workoutBuilder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            workoutSession.delegate = self
            workoutBuilder.delegate = self

            session = workoutSession
            builder = workoutBuilder

            let start = Date()
            workoutStartedAt = start
            workoutSession.startActivity(with: start)
            try await workoutBuilder.beginCollection(at: start)
            isWorkoutActive = true
            heartRateBPM = nil
        } catch {
            session = nil
            builder = nil
            isWorkoutActive = false
            hrUnavailableReason = "HR unavailable"
        }
    }

    func endWorkout() async -> (duration: TimeInterval, calories: Double) {
        let started = workoutStartedAt ?? Date()
        let duration = Date().timeIntervalSince(started)
        let calories = totalEnergyBurnedKilocalories

        guard let session, let builder else {
            resetLocalState()
            return (duration, calories)
        }

        session.end()
        do {
            try await builder.endCollection(at: Date())
            _ = try await builder.finishWorkout()
        } catch {
            // Training logging continues even if HK finish fails.
        }

        resetLocalState()
        return (duration, calories)
    }

    private func resetLocalState() {
        session = nil
        builder = nil
        isWorkoutActive = false
        heartRateBPM = nil
        totalEnergyBurnedKilocalories = 0
        workoutStartedAt = nil
    }
}

extension WatchHealthKitWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            self.isWorkoutActive = (toState == .running || toState == .prepared)
            if toState == .ended {
                self.isWorkoutActive = false
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.isWorkoutActive = false
            self.hrUnavailableReason = "HR unavailable"
        }
    }
}

extension WatchHealthKitWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        var bpm: Double?
        var kcal: Double?

        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           collectedTypes.contains(hrType),
           let quantity = workoutBuilder.statistics(for: hrType)?.mostRecentQuantity()
        {
            bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }

        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let quantity = workoutBuilder.statistics(for: energyType)?.sumQuantity()
        {
            kcal = quantity.doubleValue(for: .kilocalorie())
        }

        Task { @MainActor in
            if let bpm {
                self.heartRateBPM = bpm
                self.hrUnavailableReason = nil
            }
            if let kcal {
                self.totalEnergyBurnedKilocalories = kcal
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
