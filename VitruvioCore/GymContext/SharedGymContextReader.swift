import Foundation

/// Read-only access to the persisted active gym/role (App Group), for Watch.
public struct SharedGymContextSnapshot: Equatable, Sendable {
    public let userId: String
    public let gymId: String
    public let roleId: Int
    public let role: AppRole?

    public var isClientCapable: Bool {
        // Admin/superadmin may use Watch client companion; staff-only may not.
        role?.isClientCapable == true
    }
}

public enum SharedGymContextReader {
    private enum Keys {
        static let userId = "gymContext.activeUserId"
        static let gymId = "gymContext.activeGymId"
        static let roleId = "gymContext.activeRoleId"
    }

    public static func load(
        defaults: UserDefaults? = UserDefaults(suiteName: AppConfig.appGroupIdentifier)
    ) -> SharedGymContextSnapshot? {
        let store = defaults ?? .standard
        guard let userId = store.string(forKey: Keys.userId),
              let gymId = store.string(forKey: Keys.gymId),
              let roleIdString = store.string(forKey: Keys.roleId),
              let roleId = Int(roleIdString)
        else {
            return nil
        }
        return SharedGymContextSnapshot(
            userId: userId,
            gymId: gymId,
            roleId: roleId,
            role: AppRole(id: roleId)
        )
    }
}
