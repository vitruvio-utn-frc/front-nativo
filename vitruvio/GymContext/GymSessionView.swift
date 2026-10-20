//
//  GymSessionView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct GymSessionView: View {
    @State private var model: GymSessionModel

    init(userId: String, session: AuthSessionModel) {
        _model = State(initialValue: GymSessionModel(userId: userId, session: session))
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView("Cargando roles del gimnasio…")
            case .pickMembership:
                MembershipPickerView(model: model)
            case .active:
                activeRoot
            case .unsupportedRole:
                unsupportedView
            case .failed:
                failedView
            }
        }
        .task {
            await model.load()
        }
    }

    @ViewBuilder
    private var activeRoot: some View {
        switch model.gymContext.presentedShell {
        case .client:
            ClientRootView(model: model)
        case .staff:
            StaffRootView(model: model)
        case .admin:
            AdminRootView(model: model)
        case nil:
            unsupportedView
        @unknown default:
            unsupportedView
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Text("Rol no compatible")
                .font(.title3.bold())
            if let name = model.gymContext.activeMembership?.roleName {
                Text("El rol “\(name)” todavía no tiene pantalla en la app.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            if model.gymContext.memberships.count > 1 {
                Button("Elegir otra membresía") {
                    model.showPicker()
                }
            }
            Button("Cerrar sesión", role: .destructive) {
                Task { await model.clearAndSignOut() }
            }
        }
        .padding()
    }

    private var failedView: some View {
        VStack(spacing: 16) {
            Text("No se pudo cargar el contexto del gimnasio")
                .font(.title3.bold())
            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button("Reintentar") {
                Task { await model.load() }
            }
            .buttonStyle(.borderedProminent)
            Button("Cerrar sesión", role: .destructive) {
                Task { await model.clearAndSignOut() }
            }
        }
        .padding()
    }
}
