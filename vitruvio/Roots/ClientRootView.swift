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
                    List {
                        Section {
                            NavigationLink {
                                WatchCompanionStatusView()
                            } label: {
                                Label("Apple Watch", systemImage: "applewatch")
                            }
                        }

                        Section {
                            Text("Membership & profile land in client-membership-profile")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .tabItem { Label("Profile", systemImage: "person") }
        }
    }

    private func placeholder(_ text: String) -> some View {
        ContentUnavailableView("Client", systemImage: "figure.run", description: Text(text))
    }
}
