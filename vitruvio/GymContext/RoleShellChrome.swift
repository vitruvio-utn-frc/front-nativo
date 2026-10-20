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

    /// Role/view switching is superadmin-only. Admin stays on the admin shell.
    private var canSwitchRoleAndView: Bool {
        model.gymContext.activeMembership?.role?.hasFullShellAccess == true
    }

    private var showsSwitcher: Bool {
        canSwitchRoleAndView
            && (model.gymContext.availableShells.count > 1 || model.gymContext.memberships.count > 1)
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
                                Section("Ver como") {
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
                                Section("Gimnasio / rol") {
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
                            Label("Cambiar", systemImage: "arrow.left.arrow.right")
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar sesión", role: .destructive) {
                        Task { await model.clearAndSignOut() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let active = model.gymContext.activeMembership {
                    let shellLabel = model.gymContext.presentedShell?.displayName
                    Text(
                        shellLabel.map { "\(active.displayTitle) · viendo \($0)" }
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
