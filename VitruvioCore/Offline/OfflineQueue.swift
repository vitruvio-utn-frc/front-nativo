import Foundation
import Network

/// Offline mutation queue for training (and future) writes.
public protocol OfflineQueue: AnyObject, Sendable {
    var pendingCount: Int { get }
}

/// Writes of a training run. The API ignores client-sent ids, so every record that depends on a
/// `TrainingSessionCompletion` refers to it by its on-device `localId` and the queue resolves the
/// server id when it sends.
public enum OfflineMutationKind: String, Codable, Sendable {
    case createSessionCompletion
    case createExerciseCompletion
    case finishSessionCompletion
}

public struct QueuedSessionCompletion: Codable, Sendable {
    public var localId: String
    public var request: CreateTrainingSessionCompletionRequest

    public init(localId: String, request: CreateTrainingSessionCompletionRequest) {
        self.localId = localId
        self.request = request
    }
}

public struct QueuedExerciseCompletion: Codable, Sendable {
    public var localId: String
    public var sessionCompletionLocalId: String
    public var request: CreateExerciseCompletionRequest

    public init(localId: String, sessionCompletionLocalId: String, request: CreateExerciseCompletionRequest) {
        self.localId = localId
        self.sessionCompletionLocalId = sessionCompletionLocalId
        self.request = request
    }
}

public struct QueuedFinishSessionCompletion: Codable, Sendable {
    public var sessionCompletionLocalId: String
    public var request: UpdateTrainingSessionCompletionRequest

    public init(sessionCompletionLocalId: String, request: UpdateTrainingSessionCompletionRequest) {
        self.sessionCompletionLocalId = sessionCompletionLocalId
        self.request = request
    }
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

/// What a `flush` did: records the API accepted and records dropped because it can never accept them.
public struct OfflineFlushResult: Sendable, Equatable {
    public var sent: Int
    /// User-facing reasons, one per dropped record.
    public var discarded: [String]

    public init(sent: Int = 0, discarded: [String] = []) {
        self.sent = sent
        self.discarded = discarded
    }

    mutating func merge(_ other: OfflineFlushResult) {
        sent += other.sent
        discarded += other.discarded
    }
}

public enum OfflineQueueResolution {
    public static let kindKey = "kind"
    public static let localIdKey = "localId"
    public static let serverIdKey = "serverId"
}

public extension Notification.Name {
    /// Posted when a queued create gets its server id (`OfflineQueueResolution` keys in `userInfo`).
    static let offlineQueueDidResolveID = Notification.Name("vitruvio.offlineQueueDidResolveID")
    /// Posted whenever records are added to or removed from the queue.
    static let offlineQueueDidChange = Notification.Name("vitruvio.offlineQueueDidChange")
}

/// File-backed offline queue in the on-device caches directory.
public final class FileOfflineQueue: OfflineQueue, @unchecked Sendable {
    public static let shared = FileOfflineQueue()

    public private(set) var pendingCount: Int = 0

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private var records: [OfflineMutationRecord] = []
    private var idMap: [IDMapEntry] = []
    private var isFlushing = false
    private var flushRequestedAgain = false

    private static let maxIDMapEntries = 500

    private struct IDMapEntry: Codable {
        var localId: String
        var serverId: String
    }

    /// Records are decoded one by one so an unknown `kind` (older app version) drops only itself.
    private struct PersistedState: Codable {
        var version = 2
        var records: [LossyRecord]
        var idMap: [IDMapEntry]
    }

    private struct LossyRecord: Codable {
        var value: OfflineMutationRecord?

        init(_ value: OfflineMutationRecord) { self.value = value }

        init(from decoder: Decoder) throws {
            value = try? OfflineMutationRecord(from: decoder)
        }

        func encode(to encoder: Encoder) throws {
            try value?.encode(to: encoder)
        }
    }

    public init(fileManager: FileManager = .default, fileName: String = "offline-training-queue-v2.json") {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.fileURL = base.appending(path: fileName)
        // The previous format held prescription writes that the client no longer performs.
        try? fileManager.removeItem(at: base.appending(path: "offline-mutation-queue.json"))
        if let state = Self.load(from: fileURL, decoder: decoder) {
            self.records = state.records.compactMap(\.value)
            self.idMap = state.idMap
        }
        self.pendingCount = records.count
    }

    public func enqueue(_ kind: OfflineMutationKind, payload: Data) {
        lock.lock()
        defer { lock.unlock() }
        records.append(OfflineMutationRecord(kind: kind, payload: payload))
        pendingCount = records.count
        persistLocked()
        NotificationCenter.default.post(name: .offlineQueueDidChange, object: nil)
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

    /// Server id of a create that already went through, if any.
    public func serverId(forLocalId localId: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return idMap.last { $0.localId == localId }?.serverId
    }

    /// Sends pending mutations in order. Connectivity-type failures stop the pass (order matters because
    /// records depend on each other); a rejection the API will never accept drops that record only.
    /// Concurrent calls collapse: a call made while another is running makes it do one more pass.
    @discardableResult
    public func flush(using api: AuthenticatedAPIClient) async -> OfflineFlushResult {
        guard beginFlush() else { return OfflineFlushResult() }
        var total = OfflineFlushResult()
        repeat {
            total.merge(await flushPass(using: api))
        } while endFlushPass()
        return total
    }

    private func beginFlush() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if isFlushing {
            flushRequestedAgain = true
            return false
        }
        isFlushing = true
        return true
    }

    /// Returns `true` when another pass was requested while this one ran.
    private func endFlushPass() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if flushRequestedAgain {
            flushRequestedAgain = false
            return true
        }
        isFlushing = false
        return false
    }

    private func flushPass(using api: AuthenticatedAPIClient) async -> OfflineFlushResult {
        var result = OfflineFlushResult()
        while let record = peekAll().first {
            do {
                try await apply(record, using: api)
                remove(record.id)
                result.sent += 1
            } catch {
                switch Self.classify(error) {
                case .retryLater:
                    return result
                case .drop(let reason):
                    remove(record.id)
                    result.discarded.append(reason)
                }
            }
        }
        return result
    }

    private func apply(_ record: OfflineMutationRecord, using api: AuthenticatedAPIClient) async throws {
        switch record.kind {
        case .createSessionCompletion:
            let queued = try decode(QueuedSessionCompletion.self, from: record)
            // A crash between the POST and removing the record must not create the run twice.
            if serverId(forLocalId: queued.localId) != nil { return }
            let created: CreatedEntity = try await api.post(
                "api/training-session-completions",
                body: queued.request
            )
            resolve(.createSessionCompletion, localId: queued.localId, serverId: created.id)

        case .createExerciseCompletion:
            let queued = try decode(QueuedExerciseCompletion.self, from: record)
            if serverId(forLocalId: queued.localId) != nil { return }
            guard let sessionServerId = serverId(forLocalId: queued.sessionCompletionLocalId) else {
                throw QueueFailure.orphan
            }
            var body = queued.request
            body.trainingSessionCompletionId = sessionServerId
            let created: CreatedEntity = try await api.post("api/exercise-completions", body: body)
            CalorieSourceStore.rekey(from: queued.localId, to: created.id)
            resolve(.createExerciseCompletion, localId: queued.localId, serverId: created.id)

        case .finishSessionCompletion:
            let queued = try decode(QueuedFinishSessionCompletion.self, from: record)
            guard let sessionServerId = serverId(forLocalId: queued.sessionCompletionLocalId) else {
                throw QueueFailure.orphan
            }
            let _: CreatedEntity = try await api.put(
                "api/training-session-completions/\(sessionServerId)",
                body: queued.request
            )
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from record: OfflineMutationRecord) throws -> T {
        do {
            return try decoder.decode(type, from: record.payload)
        } catch {
            throw QueueFailure.corrupt
        }
    }

    private func resolve(_ kind: OfflineMutationKind, localId: String, serverId: String) {
        lock.lock()
        idMap.append(IDMapEntry(localId: localId, serverId: serverId))
        if idMap.count > Self.maxIDMapEntries {
            idMap.removeFirst(idMap.count - Self.maxIDMapEntries)
        }
        persistLocked()
        lock.unlock()
        NotificationCenter.default.post(
            name: .offlineQueueDidResolveID,
            object: nil,
            userInfo: [
                OfflineQueueResolution.kindKey: kind.rawValue,
                OfflineQueueResolution.localIdKey: localId,
                OfflineQueueResolution.serverIdKey: serverId,
            ]
        )
    }

    private func remove(_ id: String) {
        lock.lock()
        records.removeAll { $0.id == id }
        pendingCount = records.count
        persistLocked()
        lock.unlock()
        NotificationCenter.default.post(name: .offlineQueueDidChange, object: nil)
    }

    private func persistLocked() {
        let state = PersistedState(records: records.map(LossyRecord.init), idMap: idMap)
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL, decoder: JSONDecoder) -> PersistedState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(PersistedState.self, from: data)
    }

    /// Only the id matters to the queue: a response with other fields missing must not undo a successful write.
    private struct CreatedEntity: Decodable {
        let id: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
            id = try container.decodeLosslessString(forKey: DynamicCodingKeys("id"))
        }
    }

    // MARK: Error classification

    private enum QueueFailure: Error {
        /// The `TrainingSessionCompletion` this record depends on was never created on the server.
        case orphan
        case corrupt
    }

    private enum FlushDecision {
        case retryLater
        case drop(String)
    }

    private static func classify(_ error: Error) -> FlushDecision {
        if let failure = error as? QueueFailure {
            switch failure {
            case .orphan:
                return .drop("Se descartó un registro de entrenamiento porque su sesión no se pudo guardar.")
            case .corrupt:
                return .drop("Se descartó un registro de entrenamiento ilegible.")
            }
        }
        if error is URLError || error is CancellationError { return .retryLater }
        if let apiError = error as? APIClientError {
            switch apiError {
            case .unauthorized, .invalidResponse:
                return .retryLater
            case .httpStatus(let status), .message(let status, _):
                return isRetryable(status: status)
                    ? .retryLater
                    : .drop("El servidor rechazó un registro de entrenamiento (HTTP \(status)).")
            }
        }
        // The API accepted the write but its answer could not be read: resending would duplicate it.
        return .drop("Se descartó un registro de entrenamiento: respuesta inesperada del servidor.")
    }

    private static func isRetryable(status: Int) -> Bool {
        status >= 500 || status == 408 || status == 429
    }
}

/// On-device record of whether each exercise completion's kcal were measured or estimated.
/// The API has no field for it, so it is keyed by completion id and lives in `UserDefaults`.
public enum CalorieSourceStore {
    private static let key = "training.calorieSources.v1"
    private static let lock = NSLock()
    private static let maxEntries = 1_000

    public static func record(id: String, source: CalorieSource, defaults: UserDefaults = .standard) {
        update(defaults) { $0[id] = source.rawValue }
    }

    /// Moves an entry from the on-device id to the server id once the completion is created.
    public static func rekey(from localId: String, to serverId: String, defaults: UserDefaults = .standard) {
        update(defaults) { entries in
            guard let value = entries.removeValue(forKey: localId) else { return }
            entries[serverId] = value
        }
    }

    public static func source(forCompletionId id: String, defaults: UserDefaults = .standard) -> CalorieSource? {
        lock.lock()
        defer { lock.unlock() }
        guard let raw = (defaults.dictionary(forKey: key) as? [String: String])?[id] else { return nil }
        return CalorieSource(rawValue: raw)
    }

    private static func update(_ defaults: UserDefaults, _ body: (inout [String: String]) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var entries = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
        body(&entries)
        if entries.count > maxEntries {
            for stale in entries.keys.prefix(entries.count - maxEntries) {
                entries.removeValue(forKey: stale)
            }
        }
        defaults.set(entries, forKey: key)
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
