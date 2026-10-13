//
//  vitruvioApp.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

@main
struct vitruvioApp: App {
    @State private var session = AuthSessionModel()

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
                .task {
                    await session.restoreOnLaunch()
                }
        }
    }
}
