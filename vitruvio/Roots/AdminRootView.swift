//
//  AdminRootView.swift
//  vitruvio
//

import SwiftUI

struct AdminRootView: View {
    @Bindable var model: GymSessionModel

    var body: some View {
        TabView {
            NavigationStack {
                RoleShellChrome(model: model, title: "Admin") {
                    ContentUnavailableView(
                        "Admin",
                        systemImage: "gearshape.2",
                        description: Text("Directory, roles, and gym setup land in admin-operations")
                    )
                }
            }
            .tabItem { Label("Admin", systemImage: "gearshape.2") }
        }
    }
}
