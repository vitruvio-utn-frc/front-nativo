//
//  AppGateModel.swift
//  vitruvio
//

import Foundation
import Observation
import VitruvioCore

@MainActor
@Observable
final class AppGateModel {
    enum Phase: Equatable {
        case signedOut
        case resolving
        case onboarding(ProfilePrefill)
        case pendingApproval(userId: String)
        case ready(userId: String)
        case loadFailed
    }

    private(set) var phase: Phase = .signedOut
    private(set) var isBusy = false
    private(set) var lastError: String?
    private(set) var genders: [GenderDTO] = []

    let session: AuthSessionModel
    private var onboarding: OnboardingService

    init(session: AuthSessionModel) {
        self.session = session
        self.onboarding = OnboardingService(api: session.apiClient)
    }

    func handleAuthChange() async {
        guard session.isAuthenticated, let tokens = session.sessionController.currentTokens else {
            phase = .signedOut
            lastError = nil
            return
        }

        phase = .resolving
        lastError = nil
        isBusy = true
        defer { isBusy = false }

        do {
            let gate = try await onboarding.resolveGate(tokens: tokens)
            apply(gate)
            if case .needsOnboarding = gate {
                await loadGendersIfNeeded()
            }
        } catch {
            lastError = friendlyError(error)
            phase = .loadFailed
        }
    }

    func loadGendersIfNeeded() async {
        guard genders.isEmpty else { return }
        do {
            genders = try await onboarding.loadGenders()
        } catch {
            lastError = friendlyError(error)
        }
    }

    func submit(form: OnboardingFormState) async {
        guard let subject = session.subject else {
            lastError = "Missing subject"
            return
        }
        if let message = form.validationMessage {
            lastError = message
            return
        }
        guard let idNumber = Int(form.idNumber.trimmingCharacters(in: .whitespacesAndNewlines)),
              let genderId = Int(form.genderId) else {
            lastError = "ID number and gender must be valid integers"
            return
        }

        isBusy = true
        lastError = nil
        defer { isBusy = false }

        let request = CreateUserRequest(
            idNumber: idNumber,
            firstName: form.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: form.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: form.email.trimmingCharacters(in: .whitespacesAndNewlines),
            height: form.heightValue,
            weight: form.weightValue,
            birthDate: form.birthDateUTCMidnight,
            genderId: genderId
        )

        do {
            let gate = try await onboarding.submitProfile(subject: subject, request: request)
            apply(gate)
        } catch {
            lastError = friendlyError(error)
        }
    }

    func refreshPending(userId: String) async {
        guard let subject = session.subject else { return }
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            let gate = try await onboarding.refreshGate(subject: subject, userId: userId)
            apply(gate)
        } catch {
            lastError = friendlyError(error)
        }
    }

    private func apply(_ gate: OnboardingGate) {
        switch gate {
        case .needsOnboarding(let prefill):
            phase = .onboarding(prefill)
        case .pendingApproval(let userId):
            phase = .pendingApproval(userId: userId)
        case .ready(let userId):
            phase = .ready(userId: userId)
        @unknown default:
            phase = .loadFailed
            lastError = "Unsupported onboarding gate"
        }
    }

    private func friendlyError(_ error: Error) -> String {
        if let onboarding = error as? OnboardingError {
            switch onboarding {
            case .missingSubject:
                return "Missing Keycloak subject"
            case .validation(let message):
                return message
            case .apiMessage(let status, let message):
                return "API \(status): \(message)"
            case .unexpected:
                return "Unexpected onboarding error"
            @unknown default:
                return "Onboarding error"
            }
        }
        if let api = error as? APIClientError {
            switch api {
            case .unauthorized: return "Unauthorized"
            case .httpStatus(let code): return "HTTP \(code)"
            case .invalidResponse: return "Invalid response"
            case .message(let status, let body): return "API \(status): \(body)"
            @unknown default:
                return "API error"
            }
        }
        return error.localizedDescription
    }
}

struct OnboardingFormState: Equatable {
    var idNumber: String = ""
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var height: String = ""
    var weight: String = ""
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var genderId: String = ""

    init(prefill: ProfilePrefill = ProfilePrefill()) {
        email = prefill.email
        firstName = prefill.firstName
        lastName = prefill.lastName
    }

    var heightValue: Double { Double(height.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var weightValue: Double { Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    /// Calendar day as UTC midnight so ISO-8601 encoding matches the picked date.
    var birthDateUTCMidnight: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: birthDate)
        return calendar.date(from: parts) ?? birthDate
    }

    var validationMessage: String? {
        let trimmedId = idNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedId = Int(trimmedId), parsedId > 0 else {
            return "ID number must be a positive integer"
        }
        if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "First name is required" }
        if lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Last name is required" }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Email is required" }
        guard let parsedGender = Int(genderId), parsedGender > 0 else {
            return "Gender is required"
        }
        if heightValue <= 0 { return "Height must be positive" }
        if weightValue <= 0 { return "Weight must be positive" }
        return nil
    }
}
