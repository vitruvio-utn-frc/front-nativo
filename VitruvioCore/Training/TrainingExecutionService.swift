import Foundation

public enum TrainingExecutionError: LocalizedError, Sendable {
    case alreadyActive

    public var errorDescription: String? {
        switch self {
        case .alreadyActive: "Ya hay un entrenamiento en curso."
        }
    }
}

/// Records what the client actually does while following a prescribed session.
///
/// Every write goes through the offline queue (online it is flushed right away), so there is a single
/// code path for both modes. The prescription itself is never modified: only `TrainingSessionCompletion`
/// and `ExerciseCompletion` rows are created. Used by the iPhone UI and the Watch companion gateway.
@MainActor
@Observable
public final class TrainingExecutionService {
    public let training: TrainingService
    public let memberId: String

    public private(set) var pendingCount: Int
    /// Reasons for records the API rejected for good during the latest flushes (cleared by `dismissDiscarded`).
    public private(set) var discardedMessages: [String] = []
    public private(set) var lastSyncedCount = 0

    private let store: ActiveTrainingSessionStore
    private let queue: FileOfflineQueue
    nonisolated(unsafe) private var queueObserver: NSObjectProtocol?

    public init(
        training: TrainingService,
        memberId: String,
        store: ActiveTrainingSessionStore? = nil,
        queue: FileOfflineQueue = .shared
    ) {
        self.training = training
        self.memberId = memberId
        self.store = store ?? .shared
        self.queue = queue
        self.pendingCount = queue.pendingCount
        // Another service instance (e.g. the Watch gateway) may flush the shared queue.
        queueObserver = NotificationCenter.default.addObserver(
            forName: .offlineQueueDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pendingCount = queue.pendingCount }
        }
    }

    deinit {
        if let queueObserver {
            NotificationCenter.default.removeObserver(queueObserver)
        }
    }

    // MARK: Run lifecycle

    /// Starts following `session`. Nothing is written to the API yet: the run is recorded when its first
    /// exercise is completed, so a run abandoned without completing anything leaves no trace.
    public func start(planId: String, planName: String?, session: PrescribedSession) throws {
        guard store.snapshot == nil else { throw TrainingExecutionError.alreadyActive }
        store.replace(with: ActiveTrainingSessionSnapshot(
            trainingSessionId: session.id,
            planId: planId,
            planName: planName,
            sessionLabel: session.label,
            startedAt: Date(),
            exercises: session.makeProgress()
        ))
    }

    /// Marks or unmarks a prescribed set. Local progress only: the API has nowhere to store real reps.
    public func setSet(executionId: String, index: Int, done: Bool, energyKcal: Double? = nil) {
        store.mutate { $0.setSet(executionId: executionId, index: index, done: done, energyKcal: energyKcal) }
    }

    /// Completes a prescribed exercise and queues its `ExerciseCompletion`.
    public func completeExercise(executionId: String, energyKcal: Double? = nil) throws {
        guard let snapshot = store.snapshot else { return }
        var updated = snapshot
        guard let completed = updated.completeExercise(executionId: executionId, energyKcal: energyKcal),
              let startDate = completed.startedAt,
              let endDate = completed.completedAt
        else { return }

        if !snapshot.completionQueued {
            try queue.enqueueEncoded(
                .createSessionCompletion,
                value: QueuedSessionCompletion(
                    localId: snapshot.completionLocalId,
                    request: CreateTrainingSessionCompletionRequest(
                        trainingSessionId: snapshot.trainingSessionId,
                        memberId: memberId,
                        trainingPlanId: snapshot.planId,
                        startDate: snapshot.startedAt
                    )
                )
            )
            updated.completionQueued = true
        }

        let localId = UUID().uuidString
        let kcal = ((completed.kcal ?? 0) * 10).rounded() / 10
        try queue.enqueueEncoded(
            .createExerciseCompletion,
            value: QueuedExerciseCompletion(
                localId: localId,
                sessionCompletionLocalId: snapshot.completionLocalId,
                request: CreateExerciseCompletionRequest(
                    exerciseExecutionId: executionId,
                    trainingSessionCompletionId: snapshot.completionServerId,
                    startDate: startDate,
                    endDate: endDate,
                    caloriesBurnedInTotal: kcal
                )
            )
        )
        if let source = completed.kcalSource {
            CalorieSourceStore.record(id: localId, source: source)
        }
        store.replace(with: updated)
        scheduleFlush()
    }

    /// Ends the active run: queues the end time and clears the active session.
    /// A run with no completed exercise was never written, so ending it writes nothing.
    public func end() throws {
        guard let snapshot = store.snapshot else { return }
        guard snapshot.completionQueued else {
            store.clear()
            return
        }
        try queue.enqueueEncoded(
            .finishSessionCompletion,
            value: QueuedFinishSessionCompletion(
                sessionCompletionLocalId: snapshot.completionLocalId,
                request: UpdateTrainingSessionCompletionRequest(
                    trainingSessionId: snapshot.trainingSessionId,
                    memberId: memberId,
                    trainingPlanId: snapshot.planId,
                    startDate: snapshot.startedAt,
                    endDate: Date()
                )
            )
        )
        store.clear()
        scheduleFlush()
    }

    // MARK: Energy readings

    /// Active energy of the Watch workout for the active run, only when the reading is recent.
    public func currentEnergyReading() -> Double? {
        guard let metrics = WatchConnectivityBridge.shared.lastWorkoutMetrics,
              metrics.isWorkoutActive, metrics.isFresh(),
              metrics.trainingSessionId == nil || metrics.trainingSessionId == store.activeSessionId
        else { return nil }
        return metrics.activeEnergyKilocalories
    }

    // MARK: Sync

    public func scheduleFlush() {
        pendingCount = queue.pendingCount
        Task { await flush() }
    }

    @discardableResult
    public func flush() async -> OfflineFlushResult {
        let result = await queue.flush(using: training.api)
        pendingCount = queue.pendingCount
        lastSyncedCount = result.sent
        if !result.discarded.isEmpty {
            discardedMessages.append(contentsOf: result.discarded)
        }
        return result
    }

    public func dismissDiscarded() {
        discardedMessages = []
    }
}
