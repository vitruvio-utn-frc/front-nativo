//
//  WatchExerciseInstructions.swift
//  vitruvio.watch Watch App
//
//  Exercise instructions on Watch: playable video files, animated images (GIF) and a fallback for pages.
//  watchOS has no web view, so pages can only be opened from the iPhone.
//

import AVFoundation
import AVKit
import ImageIO
import SwiftUI
import VitruvioCore

struct WatchExerciseInstructionsView: View {
    let name: String
    let link: ExerciseMediaLink

    var body: some View {
        Group {
            switch link.kind {
            case .video:
                WatchVideoPlayer(url: link.url)
            case .image:
                WatchAnimatedImage(url: link.url)
            case .page:
                Text("Estas instrucciones solo se pueden ver desde el iPhone.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .navigationTitle(name)
    }
}

private struct WatchVideoPlayer: View {
    @State private var player: AVPlayer

    init(url: URL) {
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { player.play() }
            .onDisappear { player.pause() }
    }
}

/// Downloads an image and, when it has several frames (GIF), loops through them.
private struct WatchAnimatedImage: View {
    let url: URL
    @State private var animation: AnimatedFrames?
    @State private var failed = false

    var body: some View {
        Group {
            if let animation {
                TimelineView(.animation(minimumInterval: 1 / 15)) { context in
                    Image(decorative: animation.frame(at: context.date), scale: 1)
                        .resizable()
                        .scaledToFit()
                }
            } else if failed {
                Text("No se pudieron cargar las instrucciones.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = await Task.detached { AnimatedFrames(data: data) }.value
                animation = decoded
                failed = decoded == nil
            } catch {
                failed = true
            }
        }
    }
}

/// Decoded frames of an image, downscaled to what a Watch screen can show.
private struct AnimatedFrames: @unchecked Sendable {
    private let images: [CGImage]
    private let delays: [TimeInterval]
    private let total: TimeInterval

    private static let maxFrames = 120
    private static let maxPixelSize = 360
    private static let minDelay: TimeInterval = 0.04

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = min(CGImageSourceGetCount(source), Self.maxFrames)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize,
        ]
        var images: [CGImage] = []
        var delays: [TimeInterval] = []
        for index in 0..<count {
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { continue }
            images.append(image)
            delays.append(Self.delay(of: source, at: index))
        }
        guard !images.isEmpty else { return nil }
        self.images = images
        self.delays = delays
        self.total = delays.reduce(0, +)
    }

    func frame(at date: Date) -> CGImage {
        guard images.count > 1, total > 0 else { return images[0] }
        var remaining = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: total)
        for (image, delay) in zip(images, delays) {
            if remaining < delay { return image }
            remaining -= delay
        }
        return images[images.count - 1]
    }

    private static func delay(of source: CGImageSource, at index: Int) -> TimeInterval {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let value = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double)
            ?? 0.1
        return max(value, minDelay)
    }
}

#Preview("GIF") {
    NavigationStack {
        WatchExerciseInstructionsView(
            name: "Abdominals",
            link: ExerciseMediaLink("https://s3.santiago-alvarado.com/vitruvio/videos/0001-2gPfomN.gif")!
        )
    }
}

#Preview("Página") {
    NavigationStack {
        WatchExerciseInstructionsView(
            name: "Sentadillas",
            link: ExerciseMediaLink("https://example.com/sentadillas")!
        )
    }
}
