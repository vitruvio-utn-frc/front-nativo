//
//  WatchHealthKitWorkoutManager.swift
//  vitruvio.watch Watch App
//

import Foundation
import HealthKit
import Observation
import OSLog
import VitruvioCore

/// Runs a Watch `HKWorkoutSession` for a training run and surfaces live heart rate.
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
    private var vitalsPublishTask: Task<Void, Never>?
    /// Optional training session id tagged onto companion vitals.
    var companionTrainingSessionId: String?

    private(set) var authorizationState: AuthorizationState = .notDetermined
    private(set) var isWorkoutActive = false
    private(set) var heartRateBPM: Double?
    private(set) var totalEnergyBurnedKilocalories: Double = 0
    private(set) var hrUnavailableReason: String?
    private(set) var workoutStartedAt: Date?
    /// UUID of the last saved `HKWorkout` (diagnostics only: the API has no field for it).
    private(set) var lastSavedWorkoutId: UUID?
    private var isEnding = false
    private var isStarting = false

    private let log = Logger(subsystem: "com.santiago-alvarado.vitruvio.watch", category: "Workout")

    var canShowHeartRate: Bool {
        authorizationState == .authorized && hrUnavailableReason == nil
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            hrUnavailableReason = "Salud no disponible"
            return
        }

        guard let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else {
            authorizationState = .unavailable
            hrUnavailableReason = "Salud no disponible"
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
                hrUnavailableReason = "FC no disponible"
            } else {
                authorizationState = .authorized
                hrUnavailableReason = nil
            }
        } catch {
            authorizationState = .denied
            hrUnavailableReason = "FC no disponible"
        }
    }

    /// Starts a traditional strength workout. No-ops gracefully when auth is denied.
    func startWorkoutIfAuthorized(configuration: HKWorkoutConfiguration? = nil) async {
        // Several entry points can ask at once (launch, continue, iPhone request); one prompt is enough.
        guard !isStarting, session == nil else { return }
        isStarting = true
        defer { isStarting = false }
        if authorizationState != .authorized {
            await requestAuthorization()
        }
        guard authorizationState == .authorized else { return }
        guard session == nil else { return }
        if await recoverActiveWorkout() { return }

        let configuration = configuration ?? {
            let config = HKWorkoutConfiguration()
            // `.other` so Fitness lists the workout under a neutral name; Apple's optimized strength calories don't apply.
            config.activityType = .other
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
            startVitalsPublisher()
        } catch {
            session = nil
            builder = nil
            isWorkoutActive = false
            hrUnavailableReason = "FC no disponible"
        }
    }

    /// Ends and saves the workout. When `completionServerId` is known it is written as the workout's external
    /// identifier so the HealthKit workout can be matched to the `TrainingSessionCompletion`; when it is not,
    /// the workout is saved without it (a temporary id is never written).
    @discardableResult
    func endWorkout(completionServerId: String? = nil) async -> (duration: TimeInterval, calories: Double) {
        let started = workoutStartedAt ?? Date()
        let duration = Date().timeIntervalSince(started)
        let calories = totalEnergyBurnedKilocalories

        guard !isEnding else { return (duration, calories) }
        isEnding = true
        defer { isEnding = false }

        stopVitalsPublisher(publishFinal: true)

        guard let session, let builder else {
            resetLocalState()
            return (duration, calories)
        }

        session.end()
        let log = log
        // HealthKit can leave these calls waiting forever when the system never acknowledges the end
        // (e.g. an orphaned workout from a killed app). Bound it so the UI is never stuck behind it.
        let finished = await Self.completes(within: 10) { [weak self] in
            do {
                try await builder.endCollection(at: Date())
                if let completionServerId, !completionServerId.isEmpty {
                    try await builder.addMetadata([HKMetadataKeyExternalUUID: completionServerId])
                }
                let workout = try await builder.finishWorkout()
                await MainActor.run { self?.lastSavedWorkoutId = workout?.uuid }
                log.info("saved workout linked=\(completionServerId != nil, privacy: .public)")
            } catch {
                // Training logging continues even if HK finish fails.
                log.error("finish workout failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if !finished {
            log.error("HealthKit did not confirm the end of the workout; releasing it")
        }

        resetLocalState()
        return (duration, calories)
    }

    /// Re-attaches to, or discards, a workout the system kept alive after the app was terminated mid-run.
    /// While such a workout exists a new one cannot be closed. It is kept only when it belongs to the training
    /// run still active (it started after that run did); otherwise it is an orphan and is discarded.
    /// Returns `true` when it was adopted.
    @discardableResult
    func recoverActiveWorkout() async -> Bool {
        guard session == nil else { return false }
        guard let recovered = try? await healthStore.recoverActiveWorkoutSession() else { return false }
        let recoveredBuilder = recovered.associatedWorkoutBuilder()
        let belongsToActiveRun: Bool = await MainActor.run {
            guard let run = ActiveTrainingSessionStore.shared.snapshot,
                  let startedAt = recovered.startDate
            else { return false }
            return startedAt >= run.startedAt.addingTimeInterval(-120)
        }
        if belongsToActiveRun {
            recovered.delegate = self
            recoveredBuilder.delegate = self
            session = recovered
            builder = recoveredBuilder
            workoutStartedAt = recovered.startDate ?? Date()
            isWorkoutActive = true
            startVitalsPublisher()
            log.info("adopted a recovered workout")
            return true
        }
        recovered.end()
        _ = await Self.completes(within: 5) {
            try? await recoveredBuilder.endCollection(at: Date())
            recoveredBuilder.discardWorkout()
        }
        log.info("discarded an orphaned workout")
        return false
    }

    /// Runs `work` and reports whether it finished within `seconds`. The work is abandoned, not cancelled.
    private static func completes(within seconds: TimeInterval, _ work: @escaping @Sendable () async -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            let gate = OnceGate()
            Task {
                await work()
                if gate.claim() { continuation.resume(returning: true) }
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if gate.claim() { continuation.resume(returning: false) }
            }
        }
    }

    private func startVitalsPublisher() {
        vitalsPublishTask?.cancel()
        vitalsPublishTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isWorkoutActive else { break }
                self.publishCompanionVitals(isActive: true)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func stopVitalsPublisher(publishFinal: Bool) {
        vitalsPublishTask?.cancel()
        vitalsPublishTask = nil
        if publishFinal {
            publishCompanionVitals(isActive: false)
        }
    }

    private func publishCompanionVitals(isActive: Bool) {
        let elapsed: TimeInterval?
        if let started = workoutStartedAt {
            elapsed = Date().timeIntervalSince(started)
        } else {
            elapsed = nil
        }
        let metrics = CompanionWorkoutMetrics(
            trainingSessionId: companionTrainingSessionId,
            heartRateBPM: heartRateBPM,
            elapsedSeconds: elapsed,
            activeEnergyKilocalories: totalEnergyBurnedKilocalories > 0
                ? totalEnergyBurnedKilocalories
                : nil,
            isWorkoutActive: isActive
        )
        WatchConnectivityBridge.shared.publishWorkoutMetrics(metrics)
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
            self.hrUnavailableReason = "FC no disponible"
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

/// Lets exactly one of two racing tasks win.
private final class OnceGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
