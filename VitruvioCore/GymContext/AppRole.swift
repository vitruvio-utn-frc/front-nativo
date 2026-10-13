import Foundation

/// Canonical application roles (matches seeded API `Role` rows).
/// Permission matrix per role can grow later; for now this is the role catalog.
public enum AppRole: Int, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case cliente = 1
    case staff = 2
    case admin = 3
    case superadmin = 4

    public var id: Int { rawValue }

    /// API `Role.Name` value.
    public var name: String {
        switch self {
        case .cliente: "cliente"
        case .staff: "staff"
        case .admin: "admin"
        case .superadmin: "superadmin"
        }
    }

    /// API `Role.Description` value.
    public var description: String {
        switch self {
        case .cliente: "Miembro / cliente del gimnasio"
        case .staff: "Personal operativo del gimnasio"
        case .admin: "Administrador del gimnasio"
        case .superadmin: "Super administrador con acceso total"
        }
    }

    public init?(id: Int) {
        self.init(rawValue: id)
    }

    public init?(name: String) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let match = Self.allCases.first(where: { $0.name == normalized }) else {
            return nil
        }
        self = match
    }

    /// Default iPhone root shell for this role. `superadmin` defaults to admin.
    public var shell: RoleShell {
        switch self {
        case .cliente: .client
        case .staff: .staff
        case .admin, .superadmin: .admin
        }
    }

    /// Only superadmin can open every role shell (“View as”) in the active gym.
    /// Gym `admin` stays on the admin shell only.
    public var hasFullShellAccess: Bool {
        self == .superadmin
    }

    /// Only superadmin may list/create companies across the platform.
    /// Gym `admin` is scoped to a single company (gyms under that company only).
    public var canManageCompanies: Bool {
        self == .superadmin
    }

    /// Shells this role may present. Superadmin gets client + staff + admin.
    public var accessibleShells: [RoleShell] {
        hasFullShellAccess ? RoleShell.allCases : [shell]
    }

    /// Whether Watch may use this role for client training context.
    /// Admin/superadmin can use the client companion without a separate client membership.
    public var isClientCapable: Bool {
        self == .cliente || self == .admin || self == .superadmin
    }
}

/// iPhone root navigator kind driven by the active `AppRole`.
public enum RoleShell: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case client
    case staff
    case admin

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .client: "Client"
        case .staff: "Staff"
        case .admin: "Admin"
        }
    }
}
