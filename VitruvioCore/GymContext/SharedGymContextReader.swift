import Foundation

/// Local gym/role snapshot used by Watch after Watch Connectivity delivery.
public struct SharedGymContextSnapshot: Equatable, Sendable {
    public let userId: String
    public let gymId: String
    public let roleId: Int
    public let role: AppRole?

    public var isClientCapable: Bool {
        role?.isClientCapable == true
    }
}

public enum SharedGymContextReader {
    public enum Keys {
        public static let userId = "gymContext.activeUserId"
        public static let gymId = "gymContext.activeGymId"
        public static let roleId = "gymContext.activeRoleId"
        public static let presentedShell = "gymContext.presentedShell"
    }

    public static func load(
        defaults: UserDefaults = .standard
    ) -> SharedGymContextSnapshot? {
        guard let userId = defaults.string(forKey: Keys.userId),
              let gymId = defaults.string(forKey: Keys.gymId),
              let roleIdString = defaults.string(forKey: Keys.roleId),
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
