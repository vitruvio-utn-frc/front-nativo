import Foundation

public struct OIDCClaims: Equatable, Sendable {
    public var subject: String?
    public var email: String?
    public var givenName: String?
    public var familyName: String?
    public var name: String?

    public init(
        subject: String? = nil,
        email: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        name: String? = nil
    ) {
        self.subject = subject
        self.email = email
        self.givenName = givenName
        self.familyName = familyName
        self.name = name
    }

    public static func from(jwt: String?) -> OIDCClaims {
        guard let jwt, let json = JWTPayload.dictionary(from: jwt) else {
            return OIDCClaims()
        }
        return OIDCClaims(
            subject: json["sub"] as? String,
            email: json["email"] as? String,
            givenName: json["given_name"] as? String,
            familyName: json["family_name"] as? String,
            name: json["name"] as? String
        )
    }
}

enum JWTPayload {
    static func subject(from jwt: String) -> String? {
        dictionary(from: jwt)?["sub"] as? String
    }

    static func dictionary(from jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json
    }
}
