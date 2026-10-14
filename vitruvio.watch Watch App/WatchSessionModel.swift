//
//  WatchSessionModel.swift
//  vitruvio.watch Watch App
//

import Foundation
import Observation
import VitruvioCore

/// Watch companion session — UI state from iPhone only. No local auth tokens.
@MainActor
@Observable
final class WatchSessionModel {
    enum CompanionPhase: Equatable {
        case signedOut
        case clientReady
        case clientContextRequired
    }

    private(set) var phase: CompanionPhase = .signedOut
    private(set) var hasPhoneSession = false
    private(set) var memberId: String?
    private(set) var activeRoleName: String?
    private(set) var lastError: String?
    private(set) var latestSnapshot: CompanionSyncSnapshot?

    var isPhoneReachable: Bool { WatchConnectivityBridge.shared.isReachable }

    nonisolated(unsafe) private var syncObserver: NSObjectProtocol?

    init() {
        syncObserver = NotificationCenter.default.addObserver(
            forName: .companionSyncDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let snapshot = notification.object as? CompanionSyncSnapshot {
                    self?.apply(snapshot)
                } else {
                    self?.reloadFromBridge()
                }
            }
        }
    }

    deinit {
        if let syncObserver {
            NotificationCenter.default.removeObserver(syncObserver)
        }
    }

    func reloadFromBridge() {
        if let snapshot = WatchConnectivityBridge.shared.lastReceivedSnapshot {
            apply(snapshot)
        }
    }

    func apply(_ snapshot: CompanionSyncSnapshot) {
        latestSnapshot = snapshot
        hasPhoneSession = snapshot.hasAuth
        memberId = snapshot.userId
        if let roleId = snapshot.roleId, let id = Int(roleId) {
            activeRoleName = AppRole(id: id)?.name
        } else {
            activeRoleName = nil
        }

        guard snapshot.hasAuth else {
            phase = .signedOut
            return
        }

        let role = snapshot.roleId.flatMap { Int($0) }.flatMap(AppRole.init(id:))
        if role?.isClientCapable == true {
            phase = .clientReady
        } else {
            phase = .clientContextRequired
        }
    }

    func requestSync() {
        WatchConnectivityBridge.shared.requestFullSyncFromPhone()
        reloadFromBridge()
    }
}
