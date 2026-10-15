//
//  vitruvio_watchApp.swift
//  vitruvio.watch Watch App
//

import SwiftUI
import VitruvioCore

@main
struct vitruvio_watch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @State private var session = WatchSessionModel()

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
                .onAppear {
                    WatchConnectivityBridge.shared.activate()
                    session.requestSync()
                }
        }
    }
}
