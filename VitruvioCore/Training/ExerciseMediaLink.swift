import Foundation

public enum ExerciseMediaKind: Sendable, Equatable {
    /// File AVFoundation can play (mp4, mov, m4v).
    case video
    /// Still or animated image (gif, png, jpg, jpeg, webp).
    case image
    /// Anything else: a web page or a format the platform cannot play inline.
    case page
}

/// A usable instructions link for an exercise. Only http(s) URLs are accepted.
public struct ExerciseMediaLink: Sendable, Equatable {
    public let url: URL
    public let kind: ExerciseMediaKind

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    private static let imageExtensions: Set<String> = ["gif", "png", "jpg", "jpeg", "webp"]

    public init?(_ string: String?) {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
        else { return nil }
        self.url = url
        let ext = url.pathExtension.lowercased()
        if Self.videoExtensions.contains(ext) {
            kind = .video
        } else if Self.imageExtensions.contains(ext) {
            kind = .image
        } else {
            kind = .page
        }
    }
}
