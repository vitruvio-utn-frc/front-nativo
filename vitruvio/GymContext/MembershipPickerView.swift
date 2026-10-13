//
//  MembershipPickerView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct MembershipPickerView: View {
    @Bindable var model: GymSessionModel

    var body: some View {
        NavigationStack {
            List(model.gymContext.memberships) { membership in
                Button {
                    model.select(membership)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(membership.gymName)
                            .font(.headline)
                        Text(membership.roleName.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Choose gym & role")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Sign out", role: .destructive) {
                        Task { await model.clearAndSignOut() }
                    }
                }
            }
        }
    }
}
