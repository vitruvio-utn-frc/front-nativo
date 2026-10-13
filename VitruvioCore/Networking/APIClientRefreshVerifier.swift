import Foundation

/// Debug/test helper that proves a mocked 401 triggers exactly one refresh and one retry.
public enum APIClientRefreshVerifier {
    public static func verify401RefreshesOnce() async throws -> Bool {
        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0

            func increment() -> Int {
                lock.lock()
                defer { lock.unlock() }
                value += 1
                return value
            }

            var current: Int {
                lock.lock()
                defer { lock.unlock() }
                return value
            }
        }

        final class MockProvider: AccessTokenProviding, @unchecked Sendable {
            let refreshCount = Counter()

            func accessTokenForRequest() async throws -> String? { "expired-token" }

            func refreshAccessTokenForRequest() async throws -> String? {
                _ = refreshCount.increment()
                return "fresh-token"
            }
        }

        final class MockProtocol: URLProtocol, @unchecked Sendable {
            static let requestCount = Counter()

            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

            override func startLoading() {
                let count = Self.requestCount.increment()
                let status = count == 1 ? 401 : 200
                let response = HTTPURLResponse(
                    url: request.url ?? AppConfig.apiBaseURL,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: nil
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data("ok".utf8))
                client?.urlProtocolDidFinishLoading(self)
            }

            override func stopLoading() {}
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockProtocol.self]
        let session = URLSession(configuration: configuration)
        let provider = MockProvider()
        let client = AuthenticatedAPIClient(session: session, tokenProvider: provider)

        var request = URLRequest(url: AppConfig.apiBaseURL.appending(path: "ping"))
        request.httpMethod = "GET"
        let (_, response) = try await client.send(request)

        return response.statusCode == 200
            && provider.refreshCount.current == 1
            && MockProtocol.requestCount.current == 2
    }
}
