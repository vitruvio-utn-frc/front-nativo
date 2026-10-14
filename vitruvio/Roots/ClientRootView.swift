//
//  ClientRootView.swift
//  vitruvio
//

import SwiftUI

struct ClientRootView: View {
    @Bindable var model: GymSessionModel

    var body: some View {
        TabView {
            NavigationStack {
                RoleShellChrome(model: model, title: "Training") {
                    ClientTrainingHomeView(session: model)
                }
            }
            .tabItem { Label("Training", systemImage: "figure.run") }

            NavigationStack {
                RoleShellChrome(model: model, title: "Client") {
                    placeholder("Appointments land in client-appointments")
                }
            }
            .tabItem { Label("Schedule", systemImage: "calendar") }

            NavigationStack {
                RoleShellChrome(model: model, title: "Client") {
                    placeholder("Membership & profile land in client-membership-profile")
                }
            }
            .tabItem { Label("Profile", systemImage: "person") }
        }
    }

    private func placeholder(_ text: String) -> some View {
        ContentUnavailableView("Client", systemImage: "figure.run", description: Text(text))
    }
}
