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
                        description: Text("Clientes, ejercicios y planes: próximamente")
                    )
                }
            }
            .tabItem { Label("Operaciones", systemImage: "person.2") }
        }
    }
}
