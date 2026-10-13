//
//  PendingApprovalView.swift
//  vitruvio
//

import SwiftUI

struct PendingApprovalView: View {
    @Bindable var gate: AppGateModel
    let userId: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Pending approval")
                .font(.title2.bold())
            Text("Your profile is ready. An admin needs to assign a gym role before you can continue.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let error = gate.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Refresh status") {
                Task { await gate.refreshPending(userId: userId) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(gate.isBusy)

            Button("Sign out", role: .destructive) {
                Task { await gate.session.logout() }
            }

            if gate.isBusy {
                ProgressView()
            }
        }
        .padding()
    }
}
