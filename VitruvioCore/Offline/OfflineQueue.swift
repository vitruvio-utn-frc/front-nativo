import Foundation
import Network

/// Offline mutation queue for training (and future) writes.
public protocol OfflineQueue: AnyObject, Sendable {
    var pendingCount: Int { get }
}

public enum OfflineMutationKind: String, Codable, Sendable {
    case createExerciseExecution
    case createExerciseSet
    case createExerciseCompletion
}

public struct OfflineMutationRecord: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var kind: OfflineMutationKind
    public var payload: Data
    public var enqueuedAt: Date

    public init(id: String = UUID().uuidString, kind: OfflineMutationKind, payload: Data, enqueuedAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.payload = payload
        self.enqueuedAt = enqueuedAt
    }
}

/// File-backed offline queue in the on-device caches directory.
public final class FileOfflineQueue: OfflineQueue, @unchecked Sendable {
    public private(set) var pendingCount: Int = 0

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private var records: [OfflineMutationRecord] = []

    public init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.fileURL = base.appending(path: "offline-mutation-queue.json")
        self.records = Self.load(from: fileURL, decoder: decoder)
        self.pendingCount = records.count
    }

    public func enqueue(_ kind: OfflineMutationKind, payload: Data) {
        lock.lock()
        defer { lock.unlock() }
        records.append(OfflineMutationRecord(kind: kind, payload: payload))
        pendingCount = records.count
        persistLocked()
    }

    public func enqueueEncoded<T: Encodable>(_ kind: OfflineMutationKind, value: T) throws {
        let data = try encoder.encode(value)
        enqueue(kind, payload: data)
    }

    public func peekAll() -> [OfflineMutationRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }

    /// Attempts to flush pending mutations. Returns number successfully sent.
    @discardableResult
    public func flush(using api: AuthenticatedAPIClient) async -> Int {
        let pending = peekAll()
        guard !pending.isEmpty else { return 0 }

        var succeeded: [String] = []
        for record in pending {
            do {
                try await apply(record, using: api)
                succeeded.append(record.id)
            } catch {
                // Stop on first failure to preserve order.
                break
            }
        }

        if !succeeded.isEmpty {
            lock.lock()
            records.removeAll { succeeded.contains($0.id) }
            pendingCount = records.count
            persistLocked()
            lock.unlock()
        }
        return succeeded.count
    }

    private func apply(_ record: OfflineMutationRecord, using api: AuthenticatedAPIClient) async throws {
        switch record.kind {
        case .createExerciseExecution:
            let body = try decoder.decode(CreateExerciseExecutionRequest.self, from: record.payload)
            _ = try await api.post("api/exercise-executions", body: body) as ExerciseExecutionDTO
        case .createExerciseSet:
            let body = try decoder.decode(CreateExerciseSetRequest.self, from: record.payload)
            _ = try await api.post("api/exercise-sets", body: body) as ExerciseSetDTO
        case .createExerciseCompletion:
            let body = try decoder.decode(CreateExerciseCompletionRequest.self, from: record.payload)
            _ = try await api.post("api/exercise-completions", body: body) as ExerciseCompletionDTO
        }
    }

    private func persistLocked() {
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL, decoder: JSONDecoder) -> [OfflineMutationRecord] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode([OfflineMutationRecord].self, from: data)
        else {
            return []
        }
        return decoded
    }
}

/// No-op offline queue for wiring / previews.
public final class StubOfflineQueue: OfflineQueue, @unchecked Sendable {
    public private(set) var pendingCount = 0

    public init() {}
}

/// Observes path status for flush triggers.
@MainActor
@Observable
public final class NetworkPathMonitor {
    public private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.santiago-alvarado.vitruvio.network")

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
