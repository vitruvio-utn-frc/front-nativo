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
            Text("Pendiente de aprobación")
                .font(.title2.bold())
            Text("Tu perfil está listo. Un admin debe asignarte un rol en el gimnasio para que puedas continuar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let error = gate.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Actualizar estado") {
                Task { await gate.refreshPending(userId: userId) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(gate.isBusy)

            Button("Cerrar sesión", role: .destructive) {
                Task { await gate.session.logout() }
            }

            if gate.isBusy {
                ProgressView()
            }
        }
        .padding()
    }
}
