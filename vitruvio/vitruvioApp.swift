//
//  vitruvioApp.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

@main
struct vitruvioApp: App {
    @State private var session: AuthSessionModel
    @State private var gate: AppGateModel

    init() {
        WatchConnectivityBridge.shared.activate()
        let session = AuthSessionModel()
        CompanionPhoneGateway.shared.start(auth: session)
        _session = State(initialValue: session)
        _gate = State(initialValue: AppGateModel(session: session))
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(session: session, gate: gate)
                .task {
                    await session.restoreOnLaunch()
                    await gate.handleAuthChange()
                    await CompanionPhoneGateway.shared.publish()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await CompanionPhoneGateway.shared.publish() }
                    }
                }
        }
    }
}
