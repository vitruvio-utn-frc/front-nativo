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
            Section("Vínculo") {
                labeled("Compatible", bridge.isSupported ? "sí" : "no")
                labeled("Activación", bridge.activationStateLabel)
                labeled("Emparejado", bridge.isPaired ? "sí" : "no")
                labeled("App instalada en el Watch", bridge.isWatchAppInstalled ? "sí" : "no")
                labeled("Watch accesible", bridge.isReachable ? "sí" : "no")
                    .foregroundStyle(bridge.isReachable ? .green : .secondary)
            }

            Section("Último envío al Watch") {
                labeled("Cuándo", bridge.lastPushedAt?.formatted(date: .omitted, time: .standard) ?? "nunca")
                labeled("Contenido", bridge.lastPushSummary ?? "—")
                labeled("Reintento pendiente", bridge.hasPendingPush ? "sí" : "no")
                labeled("userInfo en cola", "\(bridge.outstandingUserInfoCount)")
            }

            Section("Snapshot enviado (al Watch)") {
                if let snap = bridge.lastPushedSnapshot {
                    labeled("hasAuth", snap.hasAuth ? "sí" : "no")
                    labeled("userId", snap.userId ?? "—")
                    labeled("roleId", snap.roleId ?? "—")
                    labeled("shell", snap.shell ?? "—")
                    labeled("planes", "\(snap.plans.count)")
                    labeled("entrenamiento", snap.trainingPlanName ?? snap.trainingSessionId ?? "ninguno")
                } else {
                    Text("Todavía no se envió ningún snapshot")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Contexto recibido (del Watch/dispositivo)") {
                Text(bridge.receivedContextSummary ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = bridge.lastError {
                Section("Último error") {
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
                    Label("Actualizar estado", systemImage: "arrow.clockwise")
                }

                Button {
                    Task {
                        isPublishing = true
                        defer { isPublishing = false }
                        await CompanionPhoneGateway.shared.publish(statusMessage: "manual-push")
                        bridge.refreshDiagnostics()
                        statusNote =
                            "Contexto enviado a las \(Date().formatted(date: .omitted, time: .standard)). En el Watch tocá Actualizar."
                    }
                } label: {
                    Label("Enviar sincronización al Watch ahora", systemImage: "applewatch.radiowaves.left.and.right")
                }
                .disabled(isPublishing || !bridge.isActivated)
            } footer: {
                Text("La sincronización usa application context (sin respuesta). Si el Watch sigue esperando, enviá desde acá y tocá Actualizar en el Watch.")
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
