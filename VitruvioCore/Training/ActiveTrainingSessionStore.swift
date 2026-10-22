import Foundation

/// In-memory + on-device durable store for the active training session.
/// Cross-device sync is via Watch Connectivity, not App Group.
/// Use `shared` in the apps so the iPhone UI, the companion gateway and the Watch mirror see one value.
@MainActor
@Observable
public final class ActiveTrainingSessionStore {
    public static let shared = ActiveTrainingSessionStore()

    public private(set) var snapshot: ActiveTrainingSessionSnapshot?

    public var activeSessionId: String? { snapshot?.trainingSessionId }
    public var activeCompletionLocalId: String? { snapshot?.completionLocalId }

    private let defaults: UserDefaults
    private let fileURL: URL
    nonisolated(unsafe) private var resolveObserver: NSObjectProtocol?

    private enum Keys {
        static let json = "training.activeSession.json"
    }

    public init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.fileURL = fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "active-training-session.json")
        self.snapshot = Self.load(defaults: self.defaults, fileURL: fileURL)
        resolveObserver = NotificationCenter.default.addObserver(
            forName: .offlineQueueDidResolveID,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let kind = notification.userInfo?[OfflineQueueResolution.kindKey] as? String,
                  kind == OfflineMutationKind.createSessionCompletion.rawValue,
                  let localId = notification.userInfo?[OfflineQueueResolution.localIdKey] as? String,
                  let serverId = notification.userInfo?[OfflineQueueResolution.serverIdKey] as? String
            else { return }
            MainActor.assumeIsolated { self?.resolveCompletion(localId: localId, serverId: serverId) }
        }
    }

    deinit {
        if let resolveObserver {
            NotificationCenter.default.removeObserver(resolveObserver)
        }
    }

    /// Replaces the active session (new run started, or Watch mirroring the phone).
    public func replace(with value: ActiveTrainingSessionSnapshot) {
        snapshot = value
        persist(value)
    }

    /// Applies an in-place change to the active session and persists it. No-op without an active session.
    @discardableResult
    public func mutate<Result>(_ body: (inout ActiveTrainingSessionSnapshot) -> Result) -> Result? {
        guard var current = snapshot else { return nil }
        let result = body(&current)
        guard current != snapshot else { return result }
        snapshot = current
        persist(current)
        return result
    }

    public func clear() {
        snapshot = nil
        defaults.removeObject(forKey: Keys.json)
        try? FileManager.default.removeItem(at: fileURL)
    }

    public func reloadFromPersistence() {
        snapshot = Self.load(defaults: defaults, fileURL: fileURL)
    }

    private func resolveCompletion(localId: String, serverId: String) {
        mutate { current in
            guard current.completionLocalId == localId, current.completionServerId != serverId else { return }
            current.completionServerId = serverId
        }
    }

    private func persist(_ value: ActiveTrainingSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: Keys.json)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Values written by an older app version fail to decode (`version`) and are dropped.
    private static func load(defaults: UserDefaults, fileURL: URL) -> ActiveTrainingSessionSnapshot? {
        if let data = defaults.data(forKey: Keys.json),
           let decoded = try? JSONDecoder().decode(ActiveTrainingSessionSnapshot.self, from: data) {
            return decoded
        }
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ActiveTrainingSessionSnapshot.self, from: data) {
            return decoded
        }
        return nil
    }
}
