//
//  ClientMembershipProfileModel.swift
//  vitruvio
//

import Foundation
import Observation
import VitruvioCore

struct ClientMembershipItem: Identifiable, Hashable {
    let userMembership: UserMembershipDTO
    let membership: MembershipDTO?
    /// Names of the gyms that sell this membership (from `gym-memberships`).
    let gymNames: [String]

    var id: String { userMembership.id }
    var name: String { membership?.name ?? "Membresía" }
}

@MainActor
@Observable
final class ClientMembershipsModel {
    private(set) var items: [ClientMembershipItem] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    let userId: String
    private(set) var gymId: String
    private(set) var gymName: String
    private let service: AdminService

    init(userId: String, gymId: String, gymName: String, api: AuthenticatedAPIClient) {
        self.userId = userId
        self.gymId = gymId
        self.gymName = gymName
        self.service = AdminService(api: api)
    }

    func updateGym(gymId: String, gymName: String) {
        self.gymId = gymId
        self.gymName = gymName
    }

    func load() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            async let mineTask = service.listUserMemberships(forMemberId: userId)
            async let catalogTask = service.listMemberships()
            async let linksTask = service.listGymMembershipLinks()
            async let gymsTask = service.listGyms()
            let (mine, catalog, links, gyms) = try await (mineTask, catalogTask, linksTask, gymsTask)
            let gymNameById = Dictionary(
                gyms.map { ($0.id.lowercased(), $0.name) },
                uniquingKeysWith: { first, _ in first }
            )

            let gymMembershipIds = Set(
                links
                    .filter { $0.gymId.caseInsensitiveCompare(gymId) == .orderedSame }
                    .map { $0.membershipId.lowercased() }
            )
            let catalogById = Dictionary(
                catalog.map { ($0.id.lowercased(), $0) },
                uniquingKeysWith: { first, _ in first }
            )
            items = mine
                .filter { gymMembershipIds.contains($0.membershipId.lowercased()) }
                .map { userMembership in
                    let membershipId = userMembership.membershipId.lowercased()
                    let names = links
                        .filter { $0.membershipId.lowercased() == membershipId }
                        .compactMap { gymNameById[$0.gymId.lowercased()] }
                        .sorted()
                    return ClientMembershipItem(
                        userMembership: userMembership,
                        membership: catalogById[membershipId],
                        gymNames: names
                    )
                }
        } catch {
            lastError = error.localizedDescription
            items = []
        }
    }
}

@MainActor
@Observable
final class ClientProfileModel {
    struct Draft: Equatable {
        var firstName = ""
        var lastName = ""
        var email = ""
        var height = ""
        var weight = ""
        var birthDate = Date()
        var photoUrl = ""
    }

    private(set) var user: UserDTO?
    private(set) var genderName: String?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var lastError: String?
    /// Bumped on every new error/status so views can show a toast even when the text repeats.
    private(set) var feedbackID = UUID()
    var draft = Draft()

    let userId: String
    private let service: UserProfileService

    init(userId: String, api: AuthenticatedAPIClient) {
        self.userId = userId
        self.service = UserProfileService(api: api)
    }

    var hasChanges: Bool {
        guard let user else { return false }
        return draft != Self.draft(from: user)
    }

    func load() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let loaded = try await service.loadUser(id: userId)
            apply(loaded)
            if let genderId = loaded.genderId {
                let genders = try? await service.loadGenders()
                genderName = genders?.first { $0.id == String(genderId) }?.name
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    /// Persists the draft; returns `true` once the API accepted it and the profile was reloaded.
    func save() async -> Bool {
        guard let user else { return false }
        lastError = nil
        guard let request = makeRequest(for: user) else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await service.updateUser(id: userId, request)
            apply(updated)
            // Reload so the UI reflects exactly what the API stored.
            await load()
            return lastError == nil
        } catch {
            fail(error.localizedDescription)
            return false
        }
    }

    private func fail(_ message: String) {
        lastError = message
        feedbackID = UUID()
    }

    func discardChanges() {
        guard let user else { return }
        draft = Self.draft(from: user)
        lastError = nil
    }

    private func apply(_ user: UserDTO) {
        self.user = user
        draft = Self.draft(from: user)
    }

    private static func draft(from user: UserDTO) -> Draft {
        Draft(
            firstName: user.firstName ?? "",
            lastName: user.lastName ?? "",
            email: user.email ?? "",
            height: user.height.map { Self.format($0) } ?? "",
            weight: user.weight.map { Self.format($0) } ?? "",
            birthDate: user.birthDate ?? Date(),
            photoUrl: user.photoUrl ?? ""
        )
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }

    private static func parse(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func makeRequest(for user: UserDTO) -> UpdateUserRequest? {
        let firstName = draft.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = draft.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstName.isEmpty else { fail("Nombre es obligatorio"); return nil }
        guard !lastName.isEmpty else { fail("Apellido es obligatorio"); return nil }
        guard !email.isEmpty else { fail("Email es obligatorio"); return nil }
        guard let height = Self.parse(draft.height), height > 0 else {
            fail("La altura debe ser positiva")
            return nil
        }
        guard let weight = Self.parse(draft.weight), weight > 0 else {
            fail("El peso debe ser positivo")
            return nil
        }
        guard let idNumber = user.idNumber, let genderId = user.genderId else {
            fail("Faltan datos del perfil (DNI o género)")
            return nil
        }
        let photo = draft.photoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        return UpdateUserRequest(
            idNumber: idNumber,
            firstName: firstName,
            lastName: lastName,
            email: email,
            photoUrl: photo.isEmpty ? nil : photo,
            height: height,
            weight: weight,
            birthDate: draft.birthDate,
            genderId: genderId
        )
    }
}
