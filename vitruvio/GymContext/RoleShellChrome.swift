//
//  RoleShellChrome.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

/// Shared chrome: active gym/role label, shell/membership switcher, sign out.
struct RoleShellChrome<Content: View>: View {
    @Bindable var model: GymSessionModel
    let title: String
    @ViewBuilder var content: () -> Content

    private var showsSwitcher: Bool {
        model.gymContext.availableShells.count > 1 || model.gymContext.memberships.count > 1
    }

    var body: some View {
        content()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsSwitcher {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if model.gymContext.availableShells.count > 1 {
                                Section("View as") {
                                    ForEach(model.gymContext.availableShells) { shell in
                                        Button {
                                            model.selectShell(shell)
                                        } label: {
                                            if shell == model.gymContext.presentedShell {
                                                Label(shell.displayName, systemImage: "checkmark")
                                            } else {
                                                Text(shell.displayName)
                                            }
                                        }
                                    }
                                }
                            }
                            if model.gymContext.memberships.count > 1 {
                                Section("Gym / role") {
                                    ForEach(model.gymContext.memberships) { membership in
                                        Button {
                                            model.select(membership)
                                        } label: {
                                            if membership.id == model.gymContext.activeMembership?.id {
                                                Label(membership.displayTitle, systemImage: "checkmark")
                                            } else {
                                                Text(membership.displayTitle)
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Switch", systemImage: "arrow.left.arrow.right")
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign out", role: .destructive) {
                        Task { await model.clearAndSignOut() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let active = model.gymContext.activeMembership {
                    let shellLabel = model.gymContext.presentedShell?.displayName
                    Text(
                        shellLabel.map { "\(active.displayTitle) · viewing \($0)" }
                            ?? active.displayTitle
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.bar)
                }
            }
    }
}
