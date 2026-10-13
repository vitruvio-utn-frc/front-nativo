import Foundation

public extension AuthenticatedAPIClient {
    private static var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: url(for: path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { throw APIClientError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await send(request)
        try Self.throwIfNeeded(response, data: data)
        return try Self.jsonDecoder.decode(T.self, from: data)
    }

    func getOptional<T: Decodable>(_ path: String) async throws -> T? {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await send(request)
        if response.statusCode == 404 {
            return nil
        }
        try Self.throwIfNeeded(response, data: data)
        if data.isEmpty { return nil }
        return try Self.jsonDecoder.decode(T.self, from: data)
    }

    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.jsonEncoder.encode(body)
        let (data, response) = try await send(request)
        try Self.throwIfNeeded(response, data: data)
        return try Self.jsonDecoder.decode(T.self, from: data)
    }

    func postEmpty<Body: Encodable>(_ path: String, body: Body) async throws {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.jsonEncoder.encode(body)
        let (data, response) = try await send(request)
        try Self.throwIfNeeded(response, data: data)
    }

    private func url(for path: String) -> URL {
        path.split(separator: "/").reduce(baseURL) { partial, component in
            partial.appending(path: String(component))
        }
    }

    private static func throwIfNeeded(_ response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            if let message = String(data: data, encoding: .utf8), !message.isEmpty {
                throw OnboardingError.apiMessage(status: response.statusCode, message: message)
            }
            throw APIClientError.httpStatus(response.statusCode)
        }
    }
}
