//
//  ContentView.swift
//  vitruvio.watch Watch App
//

import SwiftUI
import VitruvioCore

struct ContentView: View {
    @Bindable var session: WatchSessionModel

    var body: some View {
        VStack(spacing: 8) {
            Text("Vitruvio")
                .font(.headline)

            switch session.phase {
            case .signedOut:
                Text("Sign in on iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .clientReady:
                Text("Client companion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Session shared")
                    .font(.caption2)
                if let subject = session.subject {
                    Text(subject)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            case .clientContextRequired:
                Text("Client only")
                    .font(.caption)
                Text("Switch to a client role on iPhone to use Watch training.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let role = session.activeRoleName {
                    Text("Active: \(role)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Button("Refresh") {
                session.reloadSharedSession()
            }
            .font(.caption2)

            if let error = session.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .onAppear {
            session.reloadSharedSession()
        }
    }
}

#Preview {
    ContentView(session: WatchSessionModel())
}
