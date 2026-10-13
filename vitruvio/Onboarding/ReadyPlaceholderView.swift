//
//  ReadyPlaceholderView.swift
//  vitruvio
//

import SwiftUI

/// Temporary handoff until `gym-context-and-roles` mounts role roots.
struct ReadyPlaceholderView: View {
    @Bindable var gate: AppGateModel
    let userId: String

    var body: some View {
        VStack(spacing: 16) {
            Text("You're in")
                .font(.title2.bold())
            Text("Profile approved. Gym/role navigation comes next.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("user: \(userId)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button("Sign out", role: .destructive) {
                Task { await gate.session.logout() }
            }
        }
        .padding()
    }
}
