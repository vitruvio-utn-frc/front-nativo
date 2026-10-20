import Foundation

/// Admin operations against the 2025 REST API for the active gym.
public struct AdminService: Sendable {
    private let api: AuthenticatedAPIClient

    public init(api: AuthenticatedAPIClient) {
        self.api = api
    }

    // MARK: - Directory / roles

    public func loadDirectory(gymId: String) async throws -> [AdminDirectoryUser] {
        async let usersTask: [UserDTO] = api.get("api/users")
        async let rolesTask: [UserGymRoleDTO] = api.get("api/user-gym-roles")
        async let tenantsTask: [TenantDTO] = api.get("api/tenants")

        let (users, allRoles, tenants) = try await (usersTask, rolesTask, tenantsTask)
        let tenantUserIds = Set(tenants.map { $0.userId.lowercased() })
        let gymRoles = allRoles.filter { $0.gymId.caseInsensitiveCompare(gymId) == .orderedSame }

        return users.map { user in
            let roles = gymRoles
                .filter { $0.userId.caseInsensitiveCompare(user.id) == .orderedSame }
                .compactMap { AppRole(id: Int($0.roleId) ?? -1) }
            let hasAnyRoleAnywhere = allRoles.contains {
                $0.userId.caseInsensitiveCompare(user.id) == .orderedSame
            }
            let hasTenant = tenantUserIds.contains(user.id.lowercased())
            return AdminDirectoryUser(
                user: user,
                rolesInGym: roles,
                isPending: hasTenant && !hasAnyRoleAnywhere
            )
        }
        .sorted { lhs, rhs in
            if lhs.isPending != rhs.isPending { return lhs.isPending && !rhs.isPending }
            return lhs.user.displayName.localizedCaseInsensitiveCompare(rhs.user.displayName) == .orderedAscending
        }
    }

    public func assignRole(userId: String, gymId: String, roleId: Int) async throws {
        let body = CreateUserGymRoleRequest(userId: userId, gymId: gymId, roleId: roleId)
        try await api.postEmpty("api/user-gym-roles", body: body)
    }

    public func revokeRole(userId: String, gymId: String, roleId: Int) async throws {
        try await api.delete("api/user-gym-roles/\(userId)/\(gymId)/\(roleId)")
    }

    public func staff(in gymId: String, from directory: [AdminDirectoryUser]) -> [AdminDirectoryUser] {
        directory.filter { $0.rolesInGym.contains(.staff) || $0.rolesInGym.contains(.admin) || $0.rolesInGym.contains(.superadmin) }
    }

    public func clients(in gymId: String, from directory: [AdminDirectoryUser]) -> [AdminDirectoryUser] {
        directory.filter { $0.rolesInGym.contains(.cliente) }
    }

    // MARK: - Companies / gyms

    public func listCompanies() async throws -> [CompanyDTO] {
        try await api.get("api/companies")
    }

    public func createCompany(_ request: CreateCompanyRequest) async throws -> CompanyDTO {
        try await api.post("api/companies", body: request)
    }

    public func listGyms() async throws -> [GymDTO] {
        try await api.get("api/gyms")
    }

    public func createGym(_ request: CreateGymRequest) async throws -> GymDTO {
        try await api.post("api/gyms", body: request)
    }

    public func updateGym(id: String, _ request: UpdateGymRequest) async throws -> GymDTO {
        try await api.put("api/gyms/\(id)", body: request)
    }

    public func deleteGym(id: String) async throws {
        try await api.delete("api/gyms/\(id)")
    }

    /// Creates a gym and grants the creator access in that gym.
    /// Platform superadmins keep `superadmin` on the new gym; others get `admin`.
    public func createGymAndAssignAdmin(
        _ request: CreateGymRequest,
        adminUserId: String,
        creatorRole: AppRole = .admin
    ) async throws -> GymDTO {
        let gym = try await createGym(request)
        let roleId = creatorRole == .superadmin ? AppRole.superadmin.id : AppRole.admin.id
        try await assignRole(userId: adminUserId, gymId: gym.id, roleId: roleId)
        return gym
    }

    // MARK: - Memberships

    public func listMemberships() async throws -> [MembershipDTO] {
        try await api.get("api/memberships")
    }

    public func createMembership(_ request: CreateMembershipRequest) async throws -> MembershipDTO {
        try await api.post("api/memberships", body: request)
    }

    public func deleteMembership(id: String) async throws {
        try await api.delete("api/memberships/\(id)")
    }

    public func listGymMembershipLinks() async throws -> [GymMembershipLinkDTO] {
        try await api.get("api/gym-memberships")
    }

    public func linkMembership(gymId: String, membershipId: String) async throws {
        let body = CreateGymMembershipLinkRequest(gymId: gymId, membershipId: membershipId)
        try await api.postEmpty("api/gym-memberships", body: body)
    }

    public func unlinkMembership(gymId: String, membershipId: String) async throws {
        try await api.delete("api/gym-memberships/\(gymId)/\(membershipId)")
    }

    public func listGenders() async throws -> [GenderDTO] {
        try await api.get("api/genders")
    }

    public func listUserMemberships() async throws -> [UserMembershipDTO] {
        try await api.get("api/user-memberships")
    }

    public func listUserMemberships(forMemberId memberId: String) async throws -> [UserMembershipDTO] {
        let all = try await listUserMemberships()
        return all
            .filter { $0.memberId.caseInsensitiveCompare(memberId) == .orderedSame }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    public func createUserMembership(_ request: CreateUserMembershipRequest) async throws -> UserMembershipDTO {
        try await api.post("api/user-memberships", body: request)
    }

    public func deleteUserMembership(id: String) async throws {
        try await api.delete("api/user-memberships/\(id)")
    }

    // MARK: - Machines

    public func listMachineTypes() async throws -> [MachineTypeDTO] {
        try await api.get("api/machine-types")
    }

    public func createMachineType(_ request: CreateMachineTypeRequest) async throws -> MachineTypeDTO {
        try await api.post("api/machine-types", body: request)
    }

    public func updateMachineType(id: Int, _ request: UpdateMachineTypeRequest) async throws -> MachineTypeDTO {
        try await api.put("api/machine-types/\(id)", body: request)
    }

    public func listMachines() async throws -> [MachineDTO] {
        try await api.get("api/machines")
    }

    public func createMachine(_ request: CreateMachineRequest) async throws -> MachineDTO {
        try await api.post("api/machines", body: request)
    }

    public func deleteMachine(id: String) async throws {
        try await api.delete("api/machines/\(id)")
    }

    // MARK: - Appointments

    public func listActivityTypes() async throws -> [ActivityTypeDTO] {
        try await api.get("api/activity-types")
    }

    public func createActivityType(_ request: CreateActivityTypeRequest) async throws -> ActivityTypeDTO {
        try await api.post("api/activity-types", body: request)
    }

    public func listActivities() async throws -> [ActivityDTO] {
        try await api.get("api/activities")
    }

    public func createActivity(_ request: CreateActivityRequest) async throws -> ActivityDTO {
        try await api.post("api/activities", body: request)
    }

    public func listAppointments(gymId: String) async throws -> [AppointmentDTO] {
        let all: [AppointmentDTO] = try await api.get("api/appointments")
        return all
            .filter { $0.gymId.caseInsensitiveCompare(gymId) == .orderedSame }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }

    public func createAppointment(_ request: CreateAppointmentRequest) async throws -> AppointmentDTO {
        try await api.post("api/appointments", body: request)
    }

    public func updateAppointment(id: String, _ request: UpdateAppointmentRequest) async throws -> AppointmentDTO {
        try await api.put("api/appointments/\(id)", body: request)
    }

    public func deleteAppointment(id: String) async throws {
        try await api.delete("api/appointments/\(id)")
    }
}
