import Foundation
import Observation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Prescribed session row for the Watch session picker.
public struct CompanionSessionItem: Codable, Equatable, Sendable, Identifiable, Hashable {
    public var id: String
    public var label: String
    public var summary: String
    public var exerciseCount: Int

    public init(id: String, label: String, summary: String, exerciseCount: Int) {
        self.id = id
        self.label = label
        self.summary = summary
        self.exerciseCount = exerciseCount
    }

    public init(_ session: PrescribedSession) {
        self.init(
            id: session.id,
            label: session.label,
            summary: session.summary,
            exerciseCount: session.exercises.count
        )
    }
}

/// Lightweight plan row for Watch UI (no API on Watch).
public struct CompanionPlanItem: Codable, Equatable, Sendable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var sessions: [CompanionSessionItem]

    public init(id: String, name: String, sessions: [CompanionSessionItem] = []) {
        self.id = id
        self.name = name
        self.sessions = sessions
    }

    private enum CodingKeys: String, CodingKey { case id, name, sessions }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sessions = try container.decodeIfPresent([CompanionSessionItem].self, forKey: .sessions) ?? []
    }
}

/// UI state the iPhone pushes to the Watch companion. No auth tokens.
public struct CompanionSyncSnapshot: Equatable, Sendable {
    public enum Source: String, Sendable {
        case ios
        case watch
    }

    public var updatedAt: Date
    public var source: Source
    /// Whether the iPhone has an authenticated session (Watch never stores tokens).
    public var hasAuth: Bool
    public var userId: String?
    public var gymId: String?
    public var roleId: String?
    public var shell: String?
    /// The run in progress, with per-exercise progress.
    public var training: ActiveTrainingSessionSnapshot?
    public var plans: [CompanionPlanItem]
    public var statusMessage: String?

    public init(
        updatedAt: Date = Date(),
        source: Source = .ios,
        hasAuth: Bool = false,
        userId: String? = nil,
        gymId: String? = nil,
        roleId: String? = nil,
        shell: String? = nil,
        training: ActiveTrainingSessionSnapshot? = nil,
        plans: [CompanionPlanItem] = [],
        statusMessage: String? = nil
    ) {
        self.updatedAt = updatedAt
        self.source = source
        self.hasAuth = hasAuth
        self.userId = userId
        self.gymId = gymId
        self.roleId = roleId
        self.shell = shell
        self.training = training
        self.plans = plans
        self.statusMessage = statusMessage
    }

    public var trainingSnapshot: ActiveTrainingSessionSnapshot? { training }
    public var trainingSessionId: String? { training?.trainingSessionId }
    public var trainingPlanId: String? { training?.planId }
    public var trainingPlanName: String? { training?.planName }

    public static func phoneUIState(
        hasAuth: Bool,
        training: ActiveTrainingSessionSnapshot?,
        plans: [CompanionPlanItem] = [],
        statusMessage: String? = nil
    ) -> CompanionSyncSnapshot {
        let gym = SharedGymContextReader.load()
        return CompanionSyncSnapshot(
            source: .ios,
            hasAuth: hasAuth,
            userId: gym?.userId,
            gymId: gym?.gymId,
            roleId: gym.map { String($0.roleId) },
            shell: gym?.role?.shell.rawValue,
            training: training,
            plans: plans,
            statusMessage: statusMessage
        )
    }
}

public enum CompanionSyncEvent: String, Sendable {
    case authChanged
    case gymContextChanged
    case trainingSessionChanged
    case reloadRequest
}

public extension Notification.Name {
    static let companionSyncDidUpdate = Notification.Name("vitruvio.companionSyncDidUpdate")
    static let companionWorkoutMetricsDidUpdate = Notification.Name("vitruvio.companionWorkoutMetricsDidUpdate")
}

/// Live Watch HealthKit vitals for iPhone display only (not training API payload).
public struct CompanionWorkoutMetrics: Equatable, Sendable {
    public var updatedAt: Date
    public var trainingSessionId: String?
    public var heartRateBPM: Double?
    public var elapsedSeconds: TimeInterval?
    public var activeEnergyKilocalories: Double?
    public var isWorkoutActive: Bool

    public init(
        updatedAt: Date = Date(),
        trainingSessionId: String? = nil,
        heartRateBPM: Double? = nil,
        elapsedSeconds: TimeInterval? = nil,
        activeEnergyKilocalories: Double? = nil,
        isWorkoutActive: Bool = false
    ) {
        self.updatedAt = updatedAt
        self.trainingSessionId = trainingSessionId
        self.heartRateBPM = heartRateBPM
        self.elapsedSeconds = elapsedSeconds
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.isWorkoutActive = isWorkoutActive
    }

    /// Fresh enough for iPhone vitals strip (~30s).
    public func isFresh(asOf date: Date = Date(), maxAge: TimeInterval = 30) -> Bool {
        date.timeIntervalSince(updatedAt) <= maxAge
    }

    public var isDisplayable: Bool {
        isWorkoutActive && isFresh()
            && (heartRateBPM != nil || elapsedSeconds != nil || activeEnergyKilocalories != nil)
    }
}

/// Applies companion UI state locally (training mirror only — never auth tokens).
@MainActor
public enum CompanionStateApplier {
    private static var trainingStore: ActiveTrainingSessionStore { .shared }

    public static func apply(_ snapshot: CompanionSyncSnapshot) {
        // The iPhone is the source of truth for the active run; only the Watch mirrors it. Applying a
        // snapshot built a moment ago on the phone could undo a set marked in between.
#if os(watchOS)
        applyTraining(snapshot)
        applyGym(snapshot)
#endif
    }

    public static func localTrainingSnapshot() -> ActiveTrainingSessionSnapshot? {
        trainingStore.reloadFromPersistence()
        return trainingStore.snapshot
    }

#if os(watchOS)
    private static func applyGym(_ snapshot: CompanionSyncSnapshot) {
        let defaults = UserDefaults.standard
        if let userId = snapshot.userId, let gymId = snapshot.gymId, let roleId = snapshot.roleId {
            defaults.set(userId, forKey: SharedGymContextReader.Keys.userId)
            defaults.set(gymId, forKey: SharedGymContextReader.Keys.gymId)
            defaults.set(roleId, forKey: SharedGymContextReader.Keys.roleId)
            if let shell = snapshot.shell {
                defaults.set(shell, forKey: SharedGymContextReader.Keys.presentedShell)
            }
        } else if !snapshot.hasAuth {
            defaults.removeObject(forKey: SharedGymContextReader.Keys.userId)
            defaults.removeObject(forKey: SharedGymContextReader.Keys.gymId)
            defaults.removeObject(forKey: SharedGymContextReader.Keys.roleId)
            defaults.removeObject(forKey: SharedGymContextReader.Keys.presentedShell)
        }
    }
#endif

#if os(watchOS)
    private static func applyTraining(_ snapshot: CompanionSyncSnapshot) {
        if let remote = snapshot.trainingSnapshot {
            trainingStore.replace(with: remote)
        } else {
            trainingStore.clear()
        }
    }
#endif
}

/// iPhone ↔ Watch companion bridge. Watch never receives or stores auth tokens.
@MainActor
@Observable
public final class WatchConnectivityBridge: NSObject {
    public static let shared = WatchConnectivityBridge()

    public private(set) var isSupported = false
    public private(set) var isActivated = false
    public private(set) var isReachable = false
    public private(set) var isPaired = false
    public private(set) var isWatchAppInstalled = false
    public private(set) var activationStateLabel = "—"
    public private(set) var outstandingUserInfoCount = 0
    public private(set) var hasPendingPush = false
    public private(set) var lastError: String?
    public private(set) var lastReceivedSnapshot: CompanionSyncSnapshot?
    /// Last snapshot the phone attempted to deliver to the Watch (diagnostics).
    public private(set) var lastPushedSnapshot: CompanionSyncSnapshot?
    public private(set) var lastPushedAt: Date?
    public private(set) var lastPushSummary: String?
    public private(set) var receivedContextSummary: String?
    /// Watch → iPhone vitals (display only).
    public private(set) var lastWorkoutMetrics: CompanionWorkoutMetrics?

    /// Metrics suitable for the active-session vitals strip.
    public var displayableWorkoutMetrics: CompanionWorkoutMetrics? {
        guard let metrics = lastWorkoutMetrics, metrics.isDisplayable else { return nil }
        return metrics
    }

    /// iPhone installs this to answer Watch `request` / `action` messages (API stays on phone).
    public var phoneMessageHandler: (([String: Any]) async -> [String: Any])?

    private var lastAppliedUpdatedAt: Date?
    private var pendingSnapshot: CompanionSyncSnapshot?
    private var pendingEvent: CompanionSyncEvent = .reloadRequest

#if canImport(WatchConnectivity)
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }
#endif

    /// Refresh derived WCSession flags for diagnostic UI.
    public func refreshDiagnostics() {
#if canImport(WatchConnectivity)
        guard let session else {
            isSupported = false
            return
        }
        isSupported = true
        isActivated = session.activationState == .activated
        isReachable = session.isReachable
#if os(iOS)
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
#else
        isPaired = true
        isWatchAppInstalled = true
#endif
        activationStateLabel = {
            switch session.activationState {
            case .notActivated: "notActivated"
            case .inactive: "inactive"
            case .activated: "activated"
            @unknown default: "unknown"
            }
        }()
        outstandingUserInfoCount = session.outstandingUserInfoTransfers.count
        hasPendingPush = pendingSnapshot != nil
        if session.receivedApplicationContext.isEmpty {
            receivedContextSummary = "(empty)"
        } else {
            let ctx = session.receivedApplicationContext
            let auth = (ctx["hasAuth"] as? Bool) ?? (ctx["hasAuth"] as? NSNumber)?.boolValue
            receivedContextSummary = "hasAuth=\(auth.map { $0 ? "yes" : "no" } ?? "?") keys=\(ctx.count)"
        }
#if os(iOS)
        // Stale activation error from sim after unpair/reinstall while Watch is fine.
        if isReachable || isWatchAppInstalled,
           lastError == "La app del Watch no está instalada."
        {
            lastError = nil
        }
#endif
#endif
    }

    private static let listEncoder = JSONEncoder()
    private static let listDecoder = JSONDecoder()

    private override init() {
        super.init()
#if canImport(WatchConnectivity)
        isSupported = WCSession.isSupported()
#else
        isSupported = false
#endif
    }

    public func activate() {
#if canImport(WatchConnectivity)
        guard let session else { return }
        session.delegate = self
        session.activate()
#endif
    }

    public func pushSnapshot(_ snapshot: CompanionSyncSnapshot, event: CompanionSyncEvent = .reloadRequest) {
#if canImport(WatchConnectivity)
        guard let session else { return }
        guard session.activationState == .activated else {
            pendingSnapshot = snapshot
            pendingEvent = event
            return
        }
        deliver(snapshot, event: event, via: session)
#endif
    }

    /// Phone publishes UI state only (`hasAuth` flag — never tokens).
    public func pushPhoneUIState(
        hasAuth: Bool,
        training: ActiveTrainingSessionSnapshot? = nil,
        plans: [CompanionPlanItem] = [],
        statusMessage: String? = nil,
        event: CompanionSyncEvent = .reloadRequest
    ) {
        let snapshot = CompanionSyncSnapshot.phoneUIState(
            hasAuth: hasAuth,
            training: training ?? CompanionStateApplier.localTrainingSnapshot(),
            plans: plans,
            statusMessage: statusMessage
        )
        pushSnapshot(snapshot, event: event)
    }

    /// Backward-compatible shim used by older call sites.
    public func pushCurrentState(hasAuth: Bool, event: CompanionSyncEvent = .reloadRequest) {
        pushPhoneUIState(hasAuth: hasAuth, event: event)
    }

    public func pushCurrentState(
        tokens: AuthTokens?,
        training: ActiveTrainingSessionSnapshot? = nil,
        event: CompanionSyncEvent = .reloadRequest
    ) {
        // Tokens are intentionally ignored — companion does not receive credentials.
        pushPhoneUIState(hasAuth: tokens != nil, training: training, event: event)
    }

    public func requestFullSyncFromPhone() {
#if canImport(WatchConnectivity) && os(watchOS)
        guard let session else {
            lastError = "Watch Connectivity no disponible"
            return
        }
        guard session.activationState == .activated else {
            lastError = "Watch Connectivity no activado"
            return
        }

        applyReceivedApplicationContext(force: true)

        let ping: [String: Any] = ["request": "fullSync"]
        _ = session.transferUserInfo(ping)

        // Phone replies synchronously for fullSync (async MainActor hops were timing out).
        if session.isReachable {
            session.sendMessage(
                ping,
                replyHandler: { [weak self] reply in
                    Task { @MainActor in
                        self?.handleIncoming(reply, force: true)
                        if self?.lastReceivedSnapshot != nil {
                            self?.lastError = nil
                        }
                    }
                },
                errorHandler: { [weak self] error in
                    Task { @MainActor in
                        // Fall back to context / userInfo polling below.
                        if self?.lastReceivedSnapshot == nil {
                            self?.lastError = error.localizedDescription
                        }
                    }
                }
            )
        }

        Task { @MainActor in
            for delayMs in [400, 1_000, 2_000, 3_500] {
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                if self.lastReceivedSnapshot != nil {
                    self.lastError = nil
                    return
                }
                if self.applyReceivedApplicationContext(force: true) {
                    self.lastError = nil
                    return
                }
            }
            if self.lastReceivedSnapshot == nil {
                self.lastError = "Todavía no hay sincronización desde el iPhone: abrí Perfil → Apple Watch → Enviar sincronización"
            }
        }
#endif
    }

    /// Returns true if a snapshot was applied from `receivedApplicationContext`.
    @discardableResult
    public func applyReceivedApplicationContext(force: Bool = false) -> Bool {
#if canImport(WatchConnectivity)
        guard let session, !session.receivedApplicationContext.isEmpty else { return false }
        handleIncoming(session.receivedApplicationContext, force: force)
        return lastReceivedSnapshot != nil
#else
        return false
#endif
    }

    /// Watch publishes live HK vitals for iPhone display (throttled by caller).
    public func publishWorkoutMetrics(_ metrics: CompanionWorkoutMetrics) {
#if canImport(WatchConnectivity) && os(watchOS)
        guard let session, session.activationState == .activated else { return }
        var dict: [String: Any] = [
            "kind": "workoutMetrics",
            "updatedAt": metrics.updatedAt.timeIntervalSince1970,
            "isWorkoutActive": metrics.isWorkoutActive,
        ]
        if let trainingSessionId = metrics.trainingSessionId {
            dict["trainingSessionId"] = trainingSessionId
        }
        if let heartRateBPM = metrics.heartRateBPM {
            dict["heartRateBPM"] = heartRateBPM
        }
        if let elapsedSeconds = metrics.elapsedSeconds {
            dict["elapsedSeconds"] = elapsedSeconds
        }
        if let activeEnergyKilocalories = metrics.activeEnergyKilocalories {
            dict["activeEnergyKilocalories"] = activeEnergyKilocalories
        }

        if session.isReachable {
            session.sendMessage(dict, replyHandler: { _ in }, errorHandler: { _ in })
        } else if session.outstandingUserInfoTransfers.count < 2 {
            _ = session.transferUserInfo(dict)
        }
#endif
#if os(watchOS)
        lastWorkoutMetrics = metrics
#endif
    }

    /// Watch → iPhone action; reply is a fresh UI snapshot.
    public func sendWatchAction(_ action: String, params: [String: Any] = [:]) async -> CompanionSyncSnapshot? {
#if canImport(WatchConnectivity) && os(watchOS)
        guard let session, session.activationState == .activated else {
            lastError = "Watch Connectivity no está listo"
            return nil
        }
        guard session.isReachable else {
            lastError = "iPhone inaccesible"
            return nil
        }
        var message = params
        message["action"] = action
        return await withCheckedContinuation { continuation in
            session.sendMessage(
                message,
                replyHandler: { [weak self] reply in
                    Task { @MainActor in
                        self?.handleIncoming(reply, force: true)
                        continuation.resume(returning: self?.lastReceivedSnapshot)
                    }
                },
                errorHandler: { [weak self] error in
                    Task { @MainActor in
                        self?.lastError = error.localizedDescription
                        continuation.resume(returning: nil)
                    }
                }
            )
        }
#else
        return nil
#endif
    }

#if canImport(WatchConnectivity)
    private func deliver(
        _ snapshot: CompanionSyncSnapshot,
        event: CompanionSyncEvent,
        via session: WCSession
    ) {
        var context = Self.encodeContext(snapshot, event: event)
        // Avoid WCErrorCodePayloadUnsupportedTypes / identical-payload skips after reinstall.
        context["nonce"] = UUID().uuidString
        lastPushedSnapshot = snapshot

        var channels: [String] = []
        do {
            try session.updateApplicationContext(context)
            channels.append("context")
            lastPushedAt = Date()
            lastError = nil
            pendingSnapshot = nil
        } catch {
            lastError = error.localizedDescription
            pendingSnapshot = snapshot
            pendingEvent = event
        }

        // Durable copy for when the interactive channel is down. Only enqueue if idle so
        // we don't pile up transfers while the sim pair is disconnected.
        if session.outstandingUserInfoTransfers.isEmpty {
            _ = session.transferUserInfo(context)
            channels.append("userInfo")
        } else {
            channels.append("userInfoQueued")
        }

#if os(iOS)
        if session.isReachable {
            session.sendMessage(
                context,
                replyHandler: { _ in },
                errorHandler: { _ in
                    // Context + userInfo already queued; ignore interactive send failures.
                }
            )
            channels.append("message")
        }
#endif

        lastPushSummary =
            "hasAuth=\(snapshot.hasAuth ? "yes" : "no") role=\(snapshot.roleId ?? "-") plans=\(snapshot.plans.count) via=\(channels.joined(separator: "+"))"
        if lastPushedAt == nil, lastError == nil {
            lastPushedAt = Date()
        }
        refreshDiagnostics()
    }

    /// Immediate plist reply for Watch `fullSync` — must run before `replyHandler` returns.
    nonisolated private func synchronousFullSyncReplyDictionary() -> [String: Any] {
        let build = { () -> [String: Any] in
            MainActor.assumeIsolated { self.fullSyncReplyOnMain() }
        }
        if Thread.isMainThread {
            return build()
        }
        return DispatchQueue.main.sync(execute: build)
    }

    private func fullSyncReplyOnMain() -> [String: Any] {
        if let outbound = lastPushedSnapshot {
            var dict = Self.encodeContext(outbound, event: .reloadRequest)
            dict["nonce"] = UUID().uuidString
            return dict
        }
        let hasAuth = (try? KeychainTokenStore().load()) != nil
        let snap = CompanionSyncSnapshot.phoneUIState(
            hasAuth: hasAuth,
            training: CompanionStateApplier.localTrainingSnapshot()
        )
        var dict = Self.encodeContext(snap, event: .reloadRequest)
        dict["nonce"] = UUID().uuidString
        return dict
    }

    private func flushPendingOrPushLocal() {
        if let pendingSnapshot {
            pushSnapshot(pendingSnapshot, event: pendingEvent)
        }
#if os(iOS)
        if let handler = phoneMessageHandler {
            Task {
                let reply = await handler(["request": "fullSync"])
                handleIncoming(reply, force: true)
            }
        } else {
            pushPhoneUIState(hasAuth: (try? KeychainTokenStore().load()) != nil)
        }
#endif
#if os(watchOS)
        requestFullSyncFromPhone()
#endif
    }

    /// Wire format version; a receiver ignores snapshots of any other version.
    public static let wireVersion = 4

    /// Plist dictionary for a snapshot, shared by context pushes and Watch action replies.
    public static func encodeContext(
        _ snapshot: CompanionSyncSnapshot,
        event: CompanionSyncEvent = .reloadRequest
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "v": wireVersion,
            "event": event.rawValue,
            "source": snapshot.source.rawValue,
            "updatedAt": snapshot.updatedAt.timeIntervalSince1970,
            "hasAuth": snapshot.hasAuth,
        ]
        if let userId = snapshot.userId { dict["userId"] = userId }
        if let gymId = snapshot.gymId { dict["gymId"] = gymId }
        if let roleId = snapshot.roleId { dict["roleId"] = roleId }
        if let shell = snapshot.shell { dict["shell"] = shell }
        if let statusMessage = snapshot.statusMessage {
            dict["statusMessage"] = statusMessage
        }
        if let training = snapshot.training,
           let data = try? listEncoder.encode(training),
           let json = String(data: data, encoding: .utf8)
        {
            dict["trainingJSON"] = json
        }
        if let data = try? listEncoder.encode(snapshot.plans),
           let json = String(data: data, encoding: .utf8)
        {
            dict["plansJSON"] = json
        }
        return dict
    }

    private static func decodeSnapshot(from dict: [String: Any]) -> CompanionSyncSnapshot {
        let updatedAt: Date
        if let interval = dict["updatedAt"] as? TimeInterval {
            updatedAt = Date(timeIntervalSince1970: interval)
        } else if let number = dict["updatedAt"] as? NSNumber {
            updatedAt = Date(timeIntervalSince1970: number.doubleValue)
        } else {
            updatedAt = Date()
        }

        var plans: [CompanionPlanItem] = []
        if let json = dict["plansJSON"] as? String, let data = json.data(using: .utf8) {
            plans = (try? listDecoder.decode([CompanionPlanItem].self, from: data)) ?? []
        }
        var training: ActiveTrainingSessionSnapshot?
        if let json = dict["trainingJSON"] as? String, let data = json.data(using: .utf8) {
            training = try? listDecoder.decode(ActiveTrainingSessionSnapshot.self, from: data)
        }

        let source = CompanionSyncSnapshot.Source(rawValue: dict["source"] as? String ?? "") ?? .ios
        let hasAuth = (dict["hasAuth"] as? Bool)
            ?? (dict["hasAuth"] as? NSNumber)?.boolValue
            ?? false

        return CompanionSyncSnapshot(
            updatedAt: updatedAt,
            source: source,
            hasAuth: hasAuth,
            userId: dict["userId"] as? String,
            gymId: dict["gymId"] as? String,
            roleId: (dict["roleId"] as? String)
                ?? (dict["roleId"] as? NSNumber)?.stringValue,
            shell: dict["shell"] as? String,
            training: training,
            plans: plans,
            statusMessage: dict["statusMessage"] as? String
        )
    }

    private static func intValue(_ any: Any?) -> Int {
        if let value = any as? Int { return value }
        if let number = any as? NSNumber { return number.intValue }
        return 0
    }

    private func handleIncoming(_ dict: [String: Any], force: Bool = false) {
        if dict["kind"] as? String == "workoutMetrics" {
            applyWorkoutMetrics(from: dict)
            return
        }
#if os(iOS)
        // Phone must handle Watch pings that arrive via userInfo (not only sendMessage).
        if dict["request"] != nil || dict["action"] != nil, dict["hasAuth"] == nil {
            handlePhoneMessage(dict) { _ in }
            return
        }
#endif
        // Ignore action/request echoes that aren't UI snapshots.
        if dict["hasAuth"] == nil, dict["request"] != nil || dict["action"] != nil {
            return
        }
        if dict["ok"] as? Bool == false {
            lastError = (dict["error"] as? String) ?? "falló la sincronización"
            return
        }

        if let version = dict["v"], Self.intValue(version) != Self.wireVersion {
            lastError = "Las apps del iPhone y del Watch tienen versiones distintas: actualizá ambas."
            return
        }
        let snapshot = Self.decodeSnapshot(from: dict)
        // Always accept a transition to authenticated, even if timestamps race.
        let upgradingToAuth = snapshot.hasAuth && (lastReceivedSnapshot?.hasAuth != true)
        if !force, !upgradingToAuth, let lastAppliedUpdatedAt, snapshot.updatedAt <= lastAppliedUpdatedAt {
            return
        }
        lastAppliedUpdatedAt = snapshot.updatedAt
        lastReceivedSnapshot = snapshot
        lastError = nil
        CompanionStateApplier.apply(snapshot)
        NotificationCenter.default.post(name: .companionSyncDidUpdate, object: snapshot)
    }

    private func applyWorkoutMetrics(from dict: [String: Any]) {
        let updatedAt: Date
        if let interval = dict["updatedAt"] as? TimeInterval {
            updatedAt = Date(timeIntervalSince1970: interval)
        } else if let number = dict["updatedAt"] as? NSNumber {
            updatedAt = Date(timeIntervalSince1970: number.doubleValue)
        } else {
            updatedAt = Date()
        }
        let isActive = (dict["isWorkoutActive"] as? Bool)
            ?? (dict["isWorkoutActive"] as? NSNumber)?.boolValue
            ?? false
        let metrics = CompanionWorkoutMetrics(
            updatedAt: updatedAt,
            trainingSessionId: dict["trainingSessionId"] as? String,
            heartRateBPM: Self.doubleValue(dict["heartRateBPM"]),
            elapsedSeconds: Self.doubleValue(dict["elapsedSeconds"]),
            activeEnergyKilocalories: Self.doubleValue(dict["activeEnergyKilocalories"]),
            isWorkoutActive: isActive
        )
        lastWorkoutMetrics = metrics
        NotificationCenter.default.post(name: .companionWorkoutMetricsDidUpdate, object: metrics)
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let value = any as? Double { return value }
        if let number = any as? NSNumber { return number.doubleValue }
        return nil
    }

    private func handlePhoneMessage(
        _ message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
#if os(iOS)
        if let handler = phoneMessageHandler {
            Task { @MainActor in
                let reply = await handler(message)
                // replyHandler may already have been called for fullSync; safe to invoke again only for actions.
                if message["request"] as? String != "fullSync" {
                    replyHandler(reply)
                }
                if reply["hasAuth"] != nil {
                    self.handleIncoming(reply, force: true)
                }
            }
            return
        }
        // Fallback: flag-only sync without plans.
        let hasAuth = (try? KeychainTokenStore().load()) != nil
        let snapshot = CompanionSyncSnapshot.phoneUIState(
            hasAuth: hasAuth,
            training: CompanionStateApplier.localTrainingSnapshot()
        )
        pushSnapshot(snapshot, event: .reloadRequest)
        replyHandler(Self.encodeContext(snapshot, event: .reloadRequest))
#else
        replyHandler(["ok": false, "error": "not_iphone"])
#endif
    }
#endif
}

#if canImport(WatchConnectivity)
extension WatchConnectivityBridge: WCSessionDelegate {
    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isActivated = activationState == .activated
            self.isReachable = session.isReachable
            self.lastError = error?.localizedDescription
            self.refreshDiagnostics()
            guard activationState == .activated else { return }
            if !session.receivedApplicationContext.isEmpty {
                self.handleIncoming(session.receivedApplicationContext, force: true)
            }
            self.flushPendingOrPushLocal()
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.refreshDiagnostics()
            if session.isReachable { self.flushPendingOrPushLocal() }
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.handleIncoming(applicationContext) }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
#if os(iOS)
            if userInfo["request"] != nil || userInfo["action"] != nil, userInfo["hasAuth"] == nil {
                self.handlePhoneMessage(userInfo) { _ in }
                return
            }
#endif
            self.handleIncoming(userInfo, force: true)
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        // Required to avoid transfer-queue stalls when using transferUserInfo pings.
        if let error {
            Task { @MainActor in self.lastError = error.localizedDescription }
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
#if os(watchOS)
        // Phone → Watch snapshot push (no reply).
        if message["hasAuth"] != nil {
            Task { @MainActor in self.handleIncoming(message, force: true) }
            return
        }
#endif
        Task { @MainActor in
#if os(iOS)
            if message["request"] != nil || message["action"] != nil {
                self.handlePhoneMessage(message) { _ in }
                return
            }
#endif
            self.handleIncoming(message, force: true)
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
#if os(iOS)
        // CRITICAL: replyHandler must run before returning — Task{MainActor} caused timeouts.
        if message["request"] as? String == "fullSync" {
            let reply = synchronousFullSyncReplyDictionary()
            replyHandler(reply)
            Task { @MainActor in
                if let handler = self.phoneMessageHandler {
                    _ = await handler(message)
                } else {
                    self.pushPhoneUIState(hasAuth: (try? KeychainTokenStore().load()) != nil)
                }
            }
            return
        }
        if message["action"] != nil {
            Task { @MainActor in
                self.handlePhoneMessage(message, replyHandler: replyHandler)
            }
            return
        }
#endif
#if os(watchOS)
        if message["hasAuth"] != nil {
            Task { @MainActor in self.handleIncoming(message, force: true) }
            replyHandler(["ok": true])
            return
        }
#endif
        Task { @MainActor in
            self.handleIncoming(message, force: true)
            replyHandler(["ok": true])
        }
    }

#if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif
}
#endif
