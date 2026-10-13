//
//  ContentView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Vitruvio")
                .font(.largeTitle.bold())
            Text("iOS app shell")
                .foregroundStyle(.secondary)
            Text(AppConfig.appGroupIdentifier)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
