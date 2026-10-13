//
//  ContentView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct ContentView: View {
    @Bindable var session: AuthSessionModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Vitruvio")
                .font(.largeTitle.bold())

            if session.isAuthenticated {
                Text("Signed in")
                    .foregroundStyle(.secondary)
                if let subject = session.subject {
                    Text("sub: \(subject)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Button("Sign out") {
                    Task { await session.logout() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Sign in with Keycloak to continue")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Sign in") {
                    Task { await session.login() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.isBusy)
            }

            if session.isBusy {
                ProgressView()
            }

            if let error = session.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text(AppConfig.keycloakClientID)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    ContentView(session: AuthSessionModel())
}
