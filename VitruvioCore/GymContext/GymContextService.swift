import Foundation

/// Loads and enriches `UserGymRole` rows with gym/role display data.
public struct GymContextService: Sendable {
    private let api: AuthenticatedAPIClient

    public init(api: AuthenticatedAPIClient) {
        self.api = api
    }

    public func loadMemberships(forUserId userId: String) async throws -> [GymMembership] {
        async let rolesTask: [UserGymRoleDTO] = api.get("api/user-gym-roles")
        async let gymsTask: [GymDTO] = api.get("api/gyms")
        async let roleCatalogTask: [RoleDTO] = api.get("api/roles")

        let (rows, gyms, roleCatalog) = try await (rolesTask, gymsTask, roleCatalogTask)
        let gymById = Dictionary(uniqueKeysWithValues: gyms.map { ($0.id.lowercased(), $0) })
        let roleById = Dictionary(uniqueKeysWithValues: roleCatalog.map { ($0.id, $0) })

        return rows
            .filter { $0.userId.caseInsensitiveCompare(userId) == .orderedSame }
            .compactMap { row -> GymMembership? in
                guard let roleId = Int(row.roleId) else { return nil }
                let gym = gymById[row.gymId.lowercased()]
                let roleDTO = roleById[roleId]
                let appRole = AppRole(id: roleId) ?? roleDTO.flatMap { AppRole(name: $0.name) }
                return GymMembership(
                    userId: row.userId,
                    gymId: row.gymId,
                    gymName: gym?.name ?? "Gimnasio",
                    companyId: gym?.companyId,
                    roleId: roleId,
                    roleName: roleDTO?.name ?? appRole?.name ?? "role-\(roleId)",
                    role: appRole
                )
            }
            .sorted { lhs, rhs in
                if lhs.gymName != rhs.gymName { return lhs.gymName < rhs.gymName }
                return lhs.roleId < rhs.roleId
            }
    }
}
