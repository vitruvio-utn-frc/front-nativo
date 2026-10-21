//
//  ExerciseMedia.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore
import WebKit

/// Square photo thumbnail for an exercise; falls back to a placeholder when there is no usable URL.
struct ExerciseThumbnail: View {
    let urlString: String?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let url = ExerciseMedia.remoteURL(urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "dumbbell")
            .foregroundStyle(.secondary)
    }
}

/// "Ver video" button that opens the exercise video in a sheet. Renders nothing without a video URL.
struct ExerciseVideoButton: View {
    let exercise: ExerciseDTO?
    @State private var showVideo = false

    var body: some View {
        if let exercise, let url = ExerciseMedia.remoteURL(exercise.videoUrl) {
            Button {
                showVideo = true
            } label: {
                Label("Ver video", systemImage: "play.circle")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .sheet(isPresented: $showVideo) {
                ExerciseVideoSheet(title: exercise.name, url: url)
            }
        }
    }
}

struct ExerciseVideoSheet: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ExerciseMediaWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                }
        }
    }
}

enum ExerciseMedia {
    /// Only http(s) URLs are loaded; anything else is ignored.
    static func remoteURL(_ string: String?) -> URL? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    private static let imageExtensions: Set<String> = ["gif", "png", "jpg", "jpeg", "webp"]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "webm"]

    /// HTML wrapper so animated GIFs and direct video files scale to the sheet; other links load as pages.
    static func html(for url: URL) -> String? {
        let source = url.absoluteString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let ext = url.pathExtension.lowercased()
        let media: String
        if imageExtensions.contains(ext) {
            media = "<img src=\"\(source)\">"
        } else if videoExtensions.contains(ext) {
            media = "<video src=\"\(source)\" controls autoplay loop muted playsinline></video>"
        } else {
            return nil
        }
        return """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        html,body{margin:0;height:100%;background:#000}
        body{display:flex;align-items:center;justify-content:center}
        img,video{max-width:100%;max-height:100%}
        </style></head><body>\(media)</body></html>
        """
    }
}

private struct ExerciseMediaWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        if let html = ExerciseMedia.html(for: url) {
            webView.loadHTMLString(html, baseURL: url)
        } else {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
