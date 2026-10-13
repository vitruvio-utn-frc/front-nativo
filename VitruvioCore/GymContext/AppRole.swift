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
}
