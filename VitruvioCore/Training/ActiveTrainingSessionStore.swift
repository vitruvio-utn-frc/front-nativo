import Foundation

/// In-memory + App Group durable store for the active training session (iPhone + Watch).
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
        defaults: UserDefaults? = UserDefaults(suiteName: AppConfig.appGroupIdentifier),
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults ?? .standard
        let base = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier)
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = base.appending(path: "active-training-session.json")
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

    public func clear() {
        snapshot = nil
        defaults.removeObject(forKey: Keys.json)
        try? FileManager.default.removeItem(at: fileURL)
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

/// Read-only App Group access for Watch (and other companions).
public enum SharedActiveTrainingSessionReader {
    private enum Keys {
        static let json = "training.activeSession.json"
    }

    public static func load(
        defaults: UserDefaults? = UserDefaults(suiteName: AppConfig.appGroupIdentifier),
        fileManager: FileManager = .default
    ) -> ActiveTrainingSessionSnapshot? {
        let store = defaults ?? .standard
        if let data = store.data(forKey: Keys.json),
           let decoded = try? JSONDecoder().decode(ActiveTrainingSessionSnapshot.self, from: data) {
            return decoded
        }
        let base = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier)
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = base.appending(path: "active-training-session.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ActiveTrainingSessionSnapshot.self, from: data) {
            return decoded
        }
        return nil
    }
}
