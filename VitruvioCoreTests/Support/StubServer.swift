import Foundation
@testable import VitruvioCore

struct StubRequest: Sendable {
    let method: String
    let path: String
    let body: Data

    /// Decoded JSON body (empty when there is none).
    var json: [String: Any] {
        (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
    }

    var bodyText: String { String(data: body, encoding: .utf8) ?? "" }
}

enum StubResponse: Sendable {
    case json(Int, String)
    /// The request never reaches the server (`URLError.notConnectedToInternet`).
    case unreachable
}

private struct NoToken: AccessTokenProviding {
    func accessTokenForRequest() async throws -> String? { nil }
    func refreshAccessTokenForRequest() async throws -> String? { nil }
}

/// In-process stand-in for the API. Every server has its own host, so tests using it can run in parallel.
final class StubServer: @unchecked Sendable {
    typealias Handler = @Sendable (StubRequest) -> StubResponse

    let host = "\(UUID().uuidString.lowercased()).test"
    private let lock = NSLock()
    private var handler: Handler
    private var log: [StubRequest] = []

    init(_ handler: @escaping Handler) {
        self.handler = handler
        StubURLProtocol.register(self, host: host)
    }

    deinit {
        StubURLProtocol.unregister(host: host)
    }

    /// Swaps the behaviour mid-test (for example going from offline to online).
    func respond(with handler: @escaping Handler) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    var requests: [StubRequest] {
        lock.lock()
        defer { lock.unlock() }
        return log
    }

    func clearRequests() {
        lock.lock()
        log = []
        lock.unlock()
    }

    var api: AuthenticatedAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return AuthenticatedAPIClient(
            baseURL: URL(string: "http://\(host)")!,
            session: URLSession(configuration: configuration),
            tokenProvider: NoToken()
        )
    }

    fileprivate func handle(_ request: StubRequest) -> StubResponse {
        lock.lock()
        log.append(request)
        let current = handler
        lock.unlock()
        return current(request)
    }
}

final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var servers: [String: StubServer] = [:]

    fileprivate static func register(_ server: StubServer, host: String) {
        lock.lock()
        servers[host] = server
        lock.unlock()
    }

    fileprivate static func unregister(host: String) {
        lock.lock()
        servers.removeValue(forKey: host)
        lock.unlock()
    }

    private static func server(for host: String?) -> StubServer? {
        lock.lock()
        defer { lock.unlock() }
        return host.flatMap { servers[$0] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let server = Self.server(for: url.host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let stubbed = StubRequest(
            method: request.httpMethod ?? "GET",
            path: url.path,
            body: Self.readBody(of: request)
        )
        switch server.handle(stubbed) {
        case .unreachable:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case .json(let status, let body):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// Polls until `condition` holds (or the timeout passes). Background flushes make some state eventually consistent.
@MainActor
func waitUntil(timeout: TimeInterval = 5, _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return condition()
}
