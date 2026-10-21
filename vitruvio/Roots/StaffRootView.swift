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
                RoleShellChrome(model: model, title: "Clientes") {
                    StaffClientsHomeView(session: model)
                }
            }
            .tabItem { Label("Clientes", systemImage: "person.2") }

            NavigationStack {
                RoleShellChrome(model: model, title: "Ejercicios") {
                    StaffExercisesHomeView(session: model)
                }
            }
            .tabItem { Label("Ejercicios", systemImage: "dumbbell") }
        }
    }
}
