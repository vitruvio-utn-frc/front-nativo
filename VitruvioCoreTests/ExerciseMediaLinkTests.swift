import Foundation
import Testing
@testable import VitruvioCore

struct ExerciseMediaLinkTests {
    @Test(arguments: [
        ("https://cdn.test/a.mp4", ExerciseMediaKind.video),
        ("https://cdn.test/a.MOV", .video),
        ("https://cdn.test/a.m4v", .video),
        ("https://cdn.test/a.gif", .image),
        ("https://cdn.test/a.jpg", .image),
        ("https://cdn.test/a.webp", .image),
        ("https://cdn.test/a.webm", .page),
        ("https://cdn.test/watch?v=123", .page),
    ])
    func classifiesByExtension(url: String, kind: ExerciseMediaKind) {
        #expect(ExerciseMediaLink(url)?.kind == kind)
    }

    @Test(arguments: [nil, "", "   ", "ftp://cdn.test/a.mp4", "file:///a.mp4", "not a url"] as [String?])
    func rejectsMissingOrNonHTTPLinks(value: String?) {
        #expect(ExerciseMediaLink(value) == nil)
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(ExerciseMediaLink("  https://cdn.test/a.gif \n")?.url.absoluteString == "https://cdn.test/a.gif")
    }
}
