import Foundation

public struct GymRoleSelection: Equatable, Sendable, Hashable {
    public let gymID: String
    public let roleID: String

    public init(gymID: String, roleID: String) {
        self.gymID = gymID
        self.roleID = roleID
    }
}

public protocol GymContextStore: AnyObject, Sendable {
    var activeSelection: GymRoleSelection? { get }
}

/// Loads, persists, and exposes the active gym/role membership for the session.
@MainActor
@Observable
public final class GymContextController: GymContextStore {
    public private(set) var userId: String?
    public private(set) var memberships: [GymMembership] = []
    public private(set) var activeMembership: GymMembership?
    /// Shell currently shown. For superadmin this may differ from the membership's default shell.
    public private(set) var presentedShell: RoleShell?
    public var activeSelection: GymRoleSelection? { activeMembership?.selection }

    /// Shells the user can open for the active membership.
    public var availableShells: [RoleShell] {
        activeMembership?.role?.accessibleShells ?? []
    }

    private let api: AuthenticatedAPIClient
    private let defaults: UserDefaults

    private enum Keys {
        static let userId = "gymContext.activeUserId"
        static let gymId = "gymContext.activeGymId"
        static let roleId = "gymContext.activeRoleId"
        static let presentedShell = "gymContext.presentedShell"
    }

    public init(
        api: AuthenticatedAPIClient,
        defaults: UserDefaults? = UserDefaults(suiteName: AppConfig.appGroupIdentifier)
    ) {
        self.api = api
        self.defaults = defaults ?? .standard
    }

    /// Fetches memberships for `userId`, restores a still-valid selection, or auto-selects when only one.
    public func load(userId: String) async throws {
        self.userId = userId
        let loaded = try await GymContextService(api: api).loadMemberships(forUserId: userId)
        memberships = loaded

        if let restored = restorePersistedSelection(from: loaded, userId: userId) {
            activeMembership = restored
            presentedShell = restorePresentedShell(for: restored) ?? restored.role?.shell
            return
        }

        if loaded.count == 1, let only = loaded.first {
            select(only)
            return
        }

        activeMembership = nil
        presentedShell = nil
        clearPersistedSelection()
    }

    public func select(_ membership: GymMembership) {
        activeMembership = membership
        presentedShell = membership.role?.shell
        persist(membership, shell: presentedShell)
    }

    public func selectShell(_ shell: RoleShell) {
        guard availableShells.contains(shell) else { return }
        presentedShell = shell
        if let membership = activeMembership {
            persist(membership, shell: shell)
        }
    }

    /// Drops the active selection (keeps memberships) so the picker can be shown again.
    public func clearActiveSelection() {
        activeMembership = nil
        presentedShell = nil
        clearPersistedSelection()
    }

    public func clear() {
        userId = nil
        memberships = []
        activeMembership = nil
        presentedShell = nil
        clearPersistedSelection()
    }

    private func restorePersistedSelection(from memberships: [GymMembership], userId: String) -> GymMembership? {
        guard defaults.string(forKey: Keys.userId) == userId,
              let gymId = defaults.string(forKey: Keys.gymId),
              let roleId = defaults.string(forKey: Keys.roleId)
        else {
            return nil
        }
        return memberships.first {
            $0.gymId == gymId && String($0.roleId) == roleId
        }
    }

    private func restorePresentedShell(for membership: GymMembership) -> RoleShell? {
        guard let raw = defaults.string(forKey: Keys.presentedShell),
              let shell = RoleShell(rawValue: raw),
              membership.role?.accessibleShells.contains(shell) == true
        else {
            return nil
        }
        return shell
    }

    private func persist(_ membership: GymMembership, shell: RoleShell?) {
        defaults.set(membership.userId, forKey: Keys.userId)
        defaults.set(membership.gymId, forKey: Keys.gymId)
        defaults.set(String(membership.roleId), forKey: Keys.roleId)
        if let shell {
            defaults.set(shell.rawValue, forKey: Keys.presentedShell)
        } else {
            defaults.removeObject(forKey: Keys.presentedShell)
        }
    }

    private func clearPersistedSelection() {
        defaults.removeObject(forKey: Keys.userId)
        defaults.removeObject(forKey: Keys.gymId)
        defaults.removeObject(forKey: Keys.roleId)
        defaults.removeObject(forKey: Keys.presentedShell)
    }
}

/// No-op gym context for shell wiring / previews.
public final class StubGymContextStore: GymContextStore, @unchecked Sendable {
    public private(set) var activeSelection: GymRoleSelection?

    public init(activeSelection: GymRoleSelection? = nil) {
        self.activeSelection = activeSelection
    }
}
