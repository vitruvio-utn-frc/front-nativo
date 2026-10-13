//
//  vitruvio_watchApp.swift
//  vitruvio.watch Watch App
//

import SwiftUI

@main
struct vitruvio_watch_Watch_AppApp: App {
    @State private var session = WatchSessionModel()

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
        }
    }
}
