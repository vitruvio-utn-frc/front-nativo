import Foundation

/// In-memory + on-device durable store for the active training session.
/// Cross-device sync is via Watch Connectivity, not App Group.
@MainActor
@Observable
public final class ActiveTrainingSessionStore {
    public private(set) var snapshot: ActiveTrainingSessionSnapshot?

    public var activeSessionId: String? { snapshot?.sessionId }

    private let defaults: UserDefaults
    private let fileURL: URL

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
    }

    public func activate(
        sessionId: String,
        planId: String?,
        planName: String?,
        startedAt: Date = Date()
    ) {
        let next = ActiveTrainingSessionSnapshot(
            sessionId: sessionId,
            planId: planId,
            planName: planName,
            startedAt: startedAt,
            executionCount: snapshot?.sessionId == sessionId ? (snapshot?.executionCount ?? 0) : 0,
            setCount: snapshot?.sessionId == sessionId ? (snapshot?.setCount ?? 0) : 0
        )
        snapshot = next
        persist(next)
    }

    public func updateCounts(executionCount: Int, setCount: Int) {
        guard var current = snapshot else { return }
        current.executionCount = executionCount
        current.setCount = setCount
        snapshot = current
        persist(current)
    }

    public func replace(with value: ActiveTrainingSessionSnapshot) {
        snapshot = value
        persist(value)
    }

    public func clear() {
        snapshot = nil
        defaults.removeObject(forKey: Keys.json)
        try? FileManager.default.removeItem(at: fileURL)
    }

    public func reloadFromPersistence() {
        snapshot = Self.load(defaults: defaults, fileURL: fileURL)
    }

    private func persist(_ value: ActiveTrainingSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: Keys.json)
        try? data.write(to: fileURL, options: .atomic)
    }

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
