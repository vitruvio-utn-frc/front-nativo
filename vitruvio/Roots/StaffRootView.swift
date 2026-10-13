//
//  StaffRootView.swift
//  vitruvio
//

import SwiftUI

struct StaffRootView: View {
    @Bindable var model: GymSessionModel

    var body: some View {
        TabView {
            NavigationStack {
                RoleShellChrome(model: model, title: "Staff") {
                    ContentUnavailableView(
                        "Staff",
                        systemImage: "person.2",
                        description: Text("Clients, exercises, and plans land in staff-operations")
                    )
                }
            }
            .tabItem { Label("Operations", systemImage: "person.2") }
        }
    }
}
