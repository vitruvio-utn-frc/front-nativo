//
//  ContentView.swift
//  vitruvio.watch Watch App
//

import SwiftUI
import VitruvioCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Vitruvio")
                .font(.headline)
            Text("Client companion")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(AppConfig.appGroupIdentifier)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
