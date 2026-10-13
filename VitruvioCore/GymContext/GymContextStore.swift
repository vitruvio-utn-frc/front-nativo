import Foundation

/// Active gym/role context seam. Concrete membership loading lands in `gym-context-and-roles`.
public struct GymRoleSelection: Equatable, Sendable {
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

/// No-op gym context for shell wiring until role context is implemented.
public final class StubGymContextStore: GymContextStore, @unchecked Sendable {
    public private(set) var activeSelection: GymRoleSelection?

    public init() {}
}
