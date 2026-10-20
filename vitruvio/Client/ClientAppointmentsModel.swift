//
//  ClientAppointmentsModel.swift
//  vitruvio
//

import Foundation
import Observation
import VitruvioCore

@MainActor
@Observable
final class ClientAppointmentsModel {
    private(set) var myAppointments: [AppointmentDTO] = []
    private(set) var availableSlots: [AppointmentDTO] = []
    private(set) var activities: [ActivityDTO] = []
    private(set) var isLoading = false
    private(set) var isWorking = false
    private(set) var lastError: String?
    private(set) var status: String?

    let memberId: String
    private(set) var gymId: String
    private(set) var gymName: String
    let service: AdminService

    init(memberId: String, gymId: String, gymName: String, api: AuthenticatedAPIClient) {
        self.memberId = memberId
        self.gymId = gymId
        self.gymName = gymName
        self.service = AdminService(api: api)
    }

    var activityNameById: [String: String] {
        Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0.name) })
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
            async let appointmentsTask = service.listAppointments(gymId: gymId)
            async let activitiesTask = service.listActivities()
            let (appointments, listedActivities) = try await (appointmentsTask, activitiesTask)
            activities = listedActivities
            partition(appointments)
        } catch {
            lastError = error.localizedDescription
            myAppointments = []
            availableSlots = []
        }
    }

    func book(_ appointment: AppointmentDTO) async {
        guard let start = appointment.startDate, let end = appointment.endDate else {
            lastError = "El turno no tiene fechas"
            return
        }
        let open = appointment.memberId == nil
            || appointment.memberId?.caseInsensitiveCompare(memberId) == .orderedSame
        guard open else {
            lastError = "Ese turno ya está reservado"
            return
        }
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        let request = UpdateAppointmentRequest(
            gymId: appointment.gymId,
            memberId: memberId,
            activityId: appointment.activityId,
            startDate: start,
            endDate: end
        )
        do {
            _ = try await service.updateAppointment(id: appointment.id, request)
            status = "Turno reservado"
            await load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cancel(_ appointment: AppointmentDTO) async {
        guard let start = appointment.startDate, let end = appointment.endDate else {
            lastError = "El turno no tiene fechas"
            return
        }
        guard appointment.memberId?.caseInsensitiveCompare(memberId) == .orderedSame else {
            lastError = "Solo podés cancelar tus propios turnos"
            return
        }
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        let request = UpdateAppointmentRequest(
            gymId: appointment.gymId,
            memberId: nil,
            activityId: appointment.activityId,
            startDate: start,
            endDate: end
        )
        do {
            _ = try await service.updateAppointment(id: appointment.id, request)
            status = "Turno cancelado"
            await load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func partition(_ appointments: [AppointmentDTO]) {
        let now = Date()
        myAppointments = appointments
            .filter { $0.memberId?.caseInsensitiveCompare(memberId) == .orderedSame }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        availableSlots = appointments
            .filter { $0.memberId == nil }
            .filter { ($0.startDate ?? .distantPast) >= now }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }
}
