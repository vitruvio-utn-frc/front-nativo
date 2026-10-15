//
//  ContentView.swift
//  vitruvio.watch Watch App
//

import SwiftUI
import VitruvioCore

struct ContentView: View {
    @Bindable var session: WatchSessionModel

    var body: some View {
        Group {
            switch session.phase {
            case .signedOut:
                signedOutView
            case .clientContextRequired:
                clientContextRequiredView
            case .clientReady:
                WatchTrainingRootView()
            }
        }
        .onAppear {
            WatchConnectivityBridge.shared.activate()
            session.requestSync()
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionSyncDidUpdate)) { notification in
            if let snapshot = notification.object as? CompanionSyncSnapshot {
                session.apply(snapshot)
            } else {
                session.reloadFromBridge()
            }
        }
    }

    private var phoneLinkLabel: some View {
        let bridge = WatchConnectivityBridge.shared
        return Label(
            bridge.isReachable ? "iPhone linked" : (bridge.isActivated ? "Waiting for iPhone…" : "Connecting…"),
            systemImage: bridge.isReachable ? "iphone.gen3.radiowaves.left.and.right" : "iphone"
        )
        .font(.caption2)
        .foregroundStyle(bridge.isReachable ? .green : .secondary)
    }

    private var signedOutView: some View {
        VStack(spacing: 8) {
            Text("Vitruvio")
                .font(.headline)
            phoneLinkLabel
            Text("Sign in on iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let snap = session.latestSnapshot {
                Text("sync auth=\(snap.hasAuth ? "yes" : "no") role=\(snap.roleId ?? "-")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("sync: waiting…")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(WatchConnectivityBridge.shared.receivedContextSummary ?? "ctx: —")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
            Button("Refresh") {
                WatchConnectivityBridge.shared.refreshDiagnostics()
                WatchConnectivityBridge.shared.applyReceivedApplicationContext(force: true)
                session.requestSync()
            }
            .font(.caption2)
            if let error = WatchConnectivityBridge.shared.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
        }
        .padding()
    }

    private var clientContextRequiredView: some View {
        VStack(spacing: 8) {
            Text("Vitruvio")
                .font(.headline)
            phoneLinkLabel
            Text("Client only")
                .font(.caption)
            Text("Switch to a client role on iPhone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let role = session.activeRoleName {
                Text("Active: \(role)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Button("Refresh") { session.requestSync() }
                .font(.caption2)
        }
        .padding()
    }
}

#Preview {
    ContentView(session: WatchSessionModel())
}
