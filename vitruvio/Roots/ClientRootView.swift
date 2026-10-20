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
                RoleShellChrome(model: model, title: "Entrenamiento") {
                    ClientTrainingHomeView(session: model)
                }
            }
            .tabItem { Label("Entrenamiento", systemImage: "figure.run") }

            NavigationStack {
                RoleShellChrome(model: model, title: "Turnos") {
                    ClientAppointmentsHomeView(session: model)
                }
            }
            .tabItem { Label("Turnos", systemImage: "calendar") }

            NavigationStack {
                RoleShellChrome(model: model, title: "Cliente") {
                    List {
                        Section {
                            NavigationLink {
                                WatchCompanionStatusView()
                            } label: {
                                Label("Apple Watch", systemImage: "applewatch")
                            }
                        }

                        Section {
                            Text("Membresía y perfil: próximamente")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .tabItem { Label("Perfil", systemImage: "person") }
        }
    }
}
