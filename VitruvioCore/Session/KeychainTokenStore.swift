import Foundation
import Security

public enum TokenStoreError: Error, Sendable {
    case encodingFailed
    case decodingFailed
    case unexpectedStatus(OSStatus)
}

/// Persists auth tokens in Keychain, optionally using the shared access group for Watch.
public final class KeychainTokenStore: Sendable {
    public static let sharedService = "com.santiago-alvarado.vitruvio.auth"
    public static let sharedAccount = "session-tokens"

    private let service: String
    private let account: String
    private let accessGroup: String?

    public init(
        service: String = KeychainTokenStore.sharedService,
        account: String = KeychainTokenStore.sharedAccount,
        accessGroup: String? = KeychainTokenStore.resolvedAccessGroup()
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }

    public func save(_ tokens: AuthTokens) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(tokens)
        } catch {
            throw TokenStoreError.encodingFailed
        }

        try delete()

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TokenStoreError.unexpectedStatus(status)
        }
    }

    public func load() throws -> AuthTokens? {
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
            throw TokenStoreError.unexpectedStatus(status)
        }

        do {
            return try JSONDecoder().decode(AuthTokens.self, from: data)
        } catch {
            throw TokenStoreError.decodingFailed
        }
    }

    public func delete() throws {
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
            throw TokenStoreError.unexpectedStatus(status)
        }
    }

    /// Resolves `$(AppIdentifierPrefix)<suffix>` for Keychain Sharing with Watch.
    public static func resolvedAccessGroup(
        suffix: String = AppConfig.keychainAccessGroupSuffix
    ) -> String? {
        guard let prefix = bundleSeedID() else { return nil }
        return "\(prefix).\(suffix)"
    }

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
