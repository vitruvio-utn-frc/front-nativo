//
//  ContentView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct ContentView: View {
    @Bindable var session: AuthSessionModel
    @Bindable var gate: AppGateModel

    var body: some View {
        Group {
            switch gate.phase {
            case .signedOut:
                signInView
            case .resolving:
                ProgressView("Loading profile…")
            case .onboarding(let prefill):
                OnboardingView(gate: gate, prefill: prefill)
            case .pendingApproval(let userId):
                PendingApprovalView(gate: gate, userId: userId)
            case .ready(let userId):
                GymSessionView(userId: userId, session: session)
            case .loadFailed:
                loadFailedView
            }
        }
        .task(id: session.isAuthenticated) {
            await gate.handleAuthChange()
        }
    }

    private var loadFailedView: some View {
        VStack(spacing: 16) {
            Text("Couldn't load profile")
                .font(.title3.bold())
            if let error = gate.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button("Retry") {
                Task { await gate.handleAuthChange() }
            }
            .buttonStyle(.borderedProminent)
            Button("Sign out", role: .destructive) {
                Task { await session.logout() }
            }
        }
        .padding()
    }

    private var signInView: some View {
        VStack(spacing: 16) {
            Text("Vitruvio")
                .font(.largeTitle.bold())

            Text("Sign in with Keycloak to continue")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Sign in") {
                Task {
                    await session.login()
                    await gate.handleAuthChange()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.isBusy || gate.isBusy)

            if session.isBusy || gate.isBusy {
                ProgressView()
            }

            if let error = gate.lastError ?? session.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    let session = AuthSessionModel()
    ContentView(session: session, gate: AppGateModel(session: session))
}
