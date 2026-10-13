//
//  vitruvioApp.swift
//  vitruvio
//

import SwiftUI

@main
struct vitruvioApp: App {
    @State private var session: AuthSessionModel
    @State private var gate: AppGateModel

    init() {
        let session = AuthSessionModel()
        _session = State(initialValue: session)
        _gate = State(initialValue: AppGateModel(session: session))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(session: session, gate: gate)
                .task {
                    await session.restoreOnLaunch()
                    await gate.handleAuthChange()
                }
        }
    }
}
