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
                ProgressView("Loading gym roles…")
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
            Text("Unsupported role")
                .font(.title3.bold())
            if let name = model.gymContext.activeMembership?.roleName {
                Text("Role “\(name)” has no app shell yet.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            if model.gymContext.memberships.count > 1 {
                Button("Choose another membership") {
                    model.showPicker()
                }
            }
            Button("Sign out", role: .destructive) {
                Task { await model.clearAndSignOut() }
            }
        }
        .padding()
    }

    private var failedView: some View {
        VStack(spacing: 16) {
            Text("Couldn't load gym context")
                .font(.title3.bold())
            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button("Retry") {
                Task { await model.load() }
            }
            .buttonStyle(.borderedProminent)
            Button("Sign out", role: .destructive) {
                Task { await model.clearAndSignOut() }
            }
        }
        .padding()
    }
}
