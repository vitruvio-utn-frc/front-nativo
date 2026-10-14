import Foundation
import Security

public enum TokenStoreError: Error, Sendable {
    case encodingFailed
    case decodingFailed
    case unexpectedStatus(OSStatus)
}

/// Persists auth tokens in Keychain, with UserDefaults fallback (Watch simulator Keychain is flaky).
public final class KeychainTokenStore: Sendable {
    public static let sharedService = "com.santiago-alvarado.vitruvio.auth"
    public static let sharedAccount = "session-tokens"

    private static let defaultsKey = "vitruvio.auth.tokens.fallback"

    private let service: String
    private let account: String
    private let accessGroup: String?
    private let defaults: UserDefaults

    public init(
        service: String = KeychainTokenStore.sharedService,
        account: String = KeychainTokenStore.sharedAccount,
        accessGroup: String? = nil
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
        self.defaults = .standard
    }

    public func save(_ tokens: AuthTokens) throws {
        let data: Data
        do {
            data = try Self.encoder.encode(tokens)
        } catch {
            throw TokenStoreError.encodingFailed
        }

        // Always mirror to UserDefaults so Watch can recover if Keychain write fails.
        defaults.set(data, forKey: Self.defaultsKey)

        try deleteKeychainOnly()

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        // Do not throw on Keychain failure — defaults mirror is enough for companion.
        _ = status
    }

    public func load() throws -> AuthTokens? {
        if let keychainData = try loadKeychainData(),
           let tokens = try? Self.decoder.decode(AuthTokens.self, from: keychainData)
        {
            return tokens
        }
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return nil }
        do {
            return try Self.decoder.decode(AuthTokens.self, from: data)
        } catch {
            throw TokenStoreError.decodingFailed
        }
    }

    public func delete() throws {
        defaults.removeObject(forKey: Self.defaultsKey)
        try deleteKeychainOnly()
    }

    private func loadKeychainData() throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    private func deleteKeychainOnly() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            // Ignore — defaults mirror is source of truth for companion.
            return
        }
    }

    /// Resolves `$(AppIdentifierPrefix)<suffix>` for Keychain Sharing with Watch.
    public static func resolvedAccessGroup(
        suffix: String = AppConfig.keychainAccessGroupSuffix
    ) -> String? {
        guard let prefix = bundleSeedID() else { return nil }
        return "\(prefix).\(suffix)"
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    private static func bundleSeedID() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "bundle-seed-id",
            kSecAttrService as String: "bundle-seed-id",
            kSecReturnAttributes as String: true,
        ]

        var item: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            status = SecItemAdd(query as CFDictionary, &item)
        }
        guard status == errSecSuccess,
              let attributes = item as? [String: Any],
              let accessGroup = attributes[kSecAttrAccessGroup as String] as? String,
              let prefix = accessGroup.components(separatedBy: ".").first
        else {
            return nil
        }
        return prefix
    }
}
