import Foundation

/// Resolves Tenant/User bootstrap and pending-approval gate after Keycloak auth.
public final class OnboardingService: Sendable {
    private let api: AuthenticatedAPIClient

    public init(api: AuthenticatedAPIClient) {
        self.api = api
    }

    public func resolveGate(tokens: AuthTokens) async throws -> OnboardingGate {
        let claims = OIDCClaims.from(jwt: tokens.idToken ?? tokens.accessToken)
        let subject = tokens.subject ?? claims.subject
        guard let subject, !subject.isEmpty else {
            throw OnboardingError.missingSubject
        }

        if let tenant = try await fetchTenant(id: subject) {
            let roles = try await fetchRoles(forUserId: tenant.userId)
            if roles.isEmpty {
                return .pendingApproval(userId: tenant.userId)
            }
            return .ready(userId: tenant.userId)
        }

        return .needsOnboarding(ProfilePrefill(claims: claims))
    }

    public func loadGenders() async throws -> [GenderDTO] {
        try await api.get("api/genders")
    }

    public func submitProfile(
        subject: String,
        request: CreateUserRequest
    ) async throws -> OnboardingGate {
        try validate(request)

        let user: UserDTO
        if let existing = try await findExistingUser(matching: request) {
            user = existing
        } else {
            do {
                user = try await api.post("api/users", body: request)
            } catch {
                // Conflict / duplicate — try lookup again before failing.
                if let existing = try await findExistingUser(matching: request) {
                    user = existing
                } else {
                    throw error
                }
            }
        }

        if try await fetchTenant(id: subject) == nil {
            let tenantBody = CreateTenantRequest(id: subject, userId: user.id)
            do {
                try await api.postEmpty("api/tenants", body: tenantBody)
            } catch {
                // If tenant appeared concurrently, continue.
                if try await fetchTenant(id: subject) == nil {
                    throw error
                }
            }
        }

        let roles = try await fetchRoles(forUserId: user.id)
        if roles.isEmpty {
            return .pendingApproval(userId: user.id)
        }
        return .ready(userId: user.id)
    }

    public func refreshGate(subject: String, userId: String) async throws -> OnboardingGate {
        if try await fetchTenant(id: subject) == nil {
            let claims = OIDCClaims()
            return .needsOnboarding(ProfilePrefill(claims: claims))
        }
        let roles = try await fetchRoles(forUserId: userId)
        if roles.isEmpty {
            return .pendingApproval(userId: userId)
        }
        return .ready(userId: userId)
    }

    private func fetchTenant(id: String) async throws -> TenantDTO? {
        try await api.getOptional("api/tenants/\(id)")
    }

    private func fetchRoles(forUserId userId: String) async throws -> [UserGymRoleDTO] {
        let roles: [UserGymRoleDTO] = try await api.get("api/user-gym-roles")
        return roles.filter { $0.userId.caseInsensitiveCompare(userId) == .orderedSame }
    }

    private func findExistingUser(matching request: CreateUserRequest) async throws -> UserDTO? {
        // Canonical lookup: GET /api/users/by-number/{id}
        if let byNumber: UserDTO = try await api.getOptional("api/users/by-number/\(request.idNumber)") {
            return byNumber
        }

        // No by-email endpoint — best-effort scan of the list for retry after unique-email conflicts.
        if let all: [UserDTO] = try? await api.get("api/users") {
            if let match = all.first(where: {
                ($0.email ?? "").caseInsensitiveCompare(request.email) == .orderedSame
            }) {
                return match
            }
        }

        return nil
    }

    private func validate(_ request: CreateUserRequest) throws {
        func require(_ value: String, _ label: String) throws {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw OnboardingError.validation("\(label) is required")
            }
        }
        guard request.idNumber > 0 else {
            throw OnboardingError.validation("ID number must be a positive integer")
        }
        try require(request.firstName, "First name")
        try require(request.lastName, "Last name")
        try require(request.email, "Email")
        guard request.genderId > 0 else {
            throw OnboardingError.validation("Gender is required")
        }
        guard request.height > 0 else { throw OnboardingError.validation("Height must be positive") }
        guard request.weight > 0 else { throw OnboardingError.validation("Weight must be positive") }
    }
}
