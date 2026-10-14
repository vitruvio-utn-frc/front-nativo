//
//  WatchCompanionStatusView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

/// Diagnostic screen for iPhone ↔ Apple Watch companion sync.
struct WatchCompanionStatusView: View {
    @State private var bridge = WatchConnectivityBridge.shared
    @State private var isPublishing = false
    @State private var statusNote: String?

    var body: some View {
        List {
            Section("Link") {
                labeled("Supported", bridge.isSupported ? "yes" : "no")
                labeled("Activation", bridge.activationStateLabel)
                labeled("Paired", bridge.isPaired ? "yes" : "no")
                labeled("Watch app installed", bridge.isWatchAppInstalled ? "yes" : "no")
                labeled("Watch reachable", bridge.isReachable ? "yes" : "no")
                    .foregroundStyle(bridge.isReachable ? .green : .secondary)
            }

            Section("Last push to Watch") {
                labeled("When", bridge.lastPushedAt?.formatted(date: .omitted, time: .standard) ?? "never")
                labeled("Payload", bridge.lastPushSummary ?? "—")
                labeled("Pending retry", bridge.hasPendingPush ? "yes" : "no")
                labeled("Queued userInfo", "\(bridge.outstandingUserInfoCount)")
            }

            Section("Outbound snapshot (to Watch)") {
                if let snap = bridge.lastPushedSnapshot {
                    labeled("hasAuth", snap.hasAuth ? "yes" : "no")
                    labeled("userId", snap.userId ?? "—")
                    labeled("roleId", snap.roleId ?? "—")
                    labeled("shell", snap.shell ?? "—")
                    labeled("plans", "\(snap.plans.count)")
                    labeled("training", snap.trainingPlanName ?? snap.trainingSessionId ?? "none")
                } else {
                    Text("No snapshot pushed yet")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Inbound context (from Watch/device)") {
                Text(bridge.receivedContextSummary ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = bridge.lastError {
                Section("Last error") {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let statusNote {
                Section {
                    Text(statusNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    bridge.refreshDiagnostics()
                } label: {
                    Label("Refresh status", systemImage: "arrow.clockwise")
                }

                Button {
                    Task {
                        isPublishing = true
                        defer { isPublishing = false }
                        await CompanionPhoneGateway.shared.publish(statusMessage: "manual-push")
                        bridge.refreshDiagnostics()
                        statusNote =
                            "Pushed application context at \(Date().formatted(date: .omitted, time: .standard)). On Watch tap Refresh."
                    }
                } label: {
                    Label("Push sync to Watch now", systemImage: "applewatch.radiowaves.left.and.right")
                }
                .disabled(isPublishing || !bridge.isActivated)
            } footer: {
                Text("Sync uses application context (no message reply). If Watch still waits, push here then Refresh on Watch.")
                    .font(.caption2)
            }
        }
        .navigationTitle("Apple Watch")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if isPublishing { ProgressView() } }
        .onAppear { bridge.refreshDiagnostics() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            bridge.refreshDiagnostics()
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }
}
