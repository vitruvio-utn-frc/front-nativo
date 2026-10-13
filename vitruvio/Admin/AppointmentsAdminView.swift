//
//  AppointmentsAdminView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct AppointmentsAdminView: View {
    @Bindable var admin: AdminWorkspaceModel
    @State private var appointments: [AppointmentDTO] = []
    @State private var activities: [ActivityDTO] = []
    @State private var activityId: String = ""
    @State private var start = Date().addingTimeInterval(3600)
    @State private var end = Date().addingTimeInterval(7200)
    @State private var newActivityName = ""
    @State private var error: String?
    @State private var isWorking = false

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        List {
            Section("Activity") {
                if activities.isEmpty {
                    TextField("New activity name", text: $newActivityName)
                    Button("Create activity") { Task { await ensureActivity() } }
                        .disabled(newActivityName.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Picker("Activity", selection: $activityId) {
                        Text("Select").tag("")
                        ForEach(activities) { activity in
                            Text(activity.name).tag(activity.id)
                        }
                    }
                }
            }

            Section("New appointment") {
                DatePicker("Start", selection: $start)
                DatePicker("End", selection: $end)
                Button("Create slot") { Task { await create() } }
                    .disabled(activityId.isEmpty || end <= start || isWorking)
            }

            if let error {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }

            Section("Schedule · \(admin.gymName)") {
                if appointments.isEmpty {
                    Text("No appointments").foregroundStyle(.secondary)
                }
                ForEach(appointments) { appt in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activityName(for: appt.activityId))
                        if let start = appt.startDate {
                            Text(timeFormatter.string(from: start))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            Task { await delete(appt.id) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Appointments")
        .overlay { if isWorking { ProgressView() } }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func activityName(for id: String) -> String {
        activities.first { $0.id == id }?.name ?? id
    }

    private func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let a = admin.service.listAppointments(gymId: admin.gymId)
            async let act = admin.service.listActivities()
            (appointments, activities) = try await (a, act)
            if activityId.isEmpty { activityId = activities.first?.id ?? "" }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func ensureActivity() async {
        isWorking = true
        defer { isWorking = false }
        do {
            var types = try await admin.service.listActivityTypes()
            if types.isEmpty {
                let created = try await admin.service.createActivityType(
                    CreateActivityTypeRequest(name: "General")
                )
                types = [created]
            }
            guard let typeId = types.first?.id else { return }
            let activity = try await admin.service.createActivity(
                CreateActivityRequest(
                    name: newActivityName.trimmingCharacters(in: .whitespacesAndNewlines),
                    activityTypeId: typeId
                )
            )
            newActivityName = ""
            activityId = activity.id
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func create() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await admin.service.createAppointment(
                CreateAppointmentRequest(
                    gymId: admin.gymId,
                    activityId: activityId,
                    startDate: start,
                    endDate: end
                )
            )
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ id: String) async {
        do {
            try await admin.service.deleteAppointment(id: id)
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
