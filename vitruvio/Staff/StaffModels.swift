//
//  StaffModels.swift
//  vitruvio
//

import Foundation
import Observation
import VitruvioCore

// MARK: - Clients

@MainActor
@Observable
final class StaffClientsModel {
    private(set) var clients: [AdminDirectoryUser] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var feedbackID = UUID()

    private(set) var gymId: String
    private(set) var gymName: String
    private let admin: AdminService

    init(gymId: String, gymName: String, api: AuthenticatedAPIClient) {
        self.gymId = gymId
        self.gymName = gymName
        self.admin = AdminService(api: api)
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
            let directory = try await admin.loadDirectory(gymId: gymId)
            clients = admin.clients(in: gymId, from: directory)
        } catch {
            clients = []
            lastError = error.localizedDescription
            feedbackID = UUID()
        }
    }
}

// MARK: - Client summary

struct StaffMembershipSummary: Identifiable, Hashable {
    let userMembership: UserMembershipDTO
    let name: String

    var id: String { userMembership.id }
}

@MainActor
@Observable
final class StaffClientDetailModel {
    private(set) var memberships: [StaffMembershipSummary] = []
    private(set) var plans: [TrainingPlanDTO] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var feedbackID = UUID()

    let client: UserDTO
    let gymId: String
    let trainerId: String
    let training: TrainingService
    private let admin: AdminService

    init(client: UserDTO, gymId: String, trainerId: String, api: AuthenticatedAPIClient) {
        self.client = client
        self.gymId = gymId
        self.trainerId = trainerId
        self.training = TrainingService(api: api)
        self.admin = AdminService(api: api)
    }

    func load() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            async let mineTask = admin.listUserMemberships(forMemberId: client.id)
            async let catalogTask = admin.listMemberships()
            async let linksTask = admin.listGymMembershipLinks()
            async let plansTask = training.listPlans(forMemberId: client.id)
            let (mine, catalog, links, loadedPlans) = try await (mineTask, catalogTask, linksTask, plansTask)

            let gymMembershipIds = Set(
                links
                    .filter { $0.gymId.caseInsensitiveCompare(gymId) == .orderedSame }
                    .map { $0.membershipId.lowercased() }
            )
            let nameById = Dictionary(
                catalog.map { ($0.id.lowercased(), $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
            memberships = mine
                .filter { gymMembershipIds.contains($0.membershipId.lowercased()) }
                .map { StaffMembershipSummary(userMembership: $0, name: nameById[$0.membershipId.lowercased()] ?? "Membresía") }
            plans = loadedPlans
        } catch {
            lastError = error.localizedDescription
            feedbackID = UUID()
        }
    }

    func createPlan(_ request: TrainingPlanRequest) async -> TrainingPlanDTO? {
        lastError = nil
        do {
            let plan = try await training.createPlan(request)
            await load()
            return plan
        } catch {
            lastError = error.localizedDescription
            feedbackID = UUID()
            return nil
        }
    }

    func deletePlan(_ plan: TrainingPlanDTO) async -> Bool {
        lastError = nil
        do {
            try await training.deletePlan(id: plan.id)
            await load()
            return true
        } catch {
            lastError = error.localizedDescription
            feedbackID = UUID()
            return false
        }
    }
}

// MARK: - Exercises

@MainActor
@Observable
final class StaffExercisesModel {
    private(set) var exercises: [ExerciseDTO] = []
    private(set) var exerciseTypes: [ExerciseTypeDTO] = []
    private(set) var machineTypes: [MachineTypeDTO] = []
    private(set) var isLoading = false
    private(set) var isWorking = false
    private(set) var lastError: String?
    private(set) var feedbackID = UUID()

    private let training: TrainingService
    private let admin: AdminService

    init(api: AuthenticatedAPIClient) {
        self.training = TrainingService(api: api)
        self.admin = AdminService(api: api)
    }

    var exerciseTypeNameById: [Int: String] {
        Dictionary(exerciseTypes.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    var machineTypeNameById: [Int: String] {
        Dictionary(machineTypes.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    func load() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            async let exercisesTask = training.listExercises()
            async let typesTask = training.listExerciseTypes()
            async let machinesTask = admin.listMachineTypes()
            let (loaded, types, machines) = try await (exercisesTask, typesTask, machinesTask)
            exercises = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            exerciseTypes = types
            machineTypes = machines
        } catch {
            fail(error)
        }
    }

    /// Creates (`id == nil`) or updates an exercise, then reloads the list. Returns `true` on success.
    func save(id: String?, _ request: ExerciseRequest) async -> Bool {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        do {
            if let id {
                _ = try await training.updateExercise(id: id, request)
            } else {
                _ = try await training.createExercise(request)
            }
            await load()
            return lastError == nil
        } catch {
            fail(error)
            return false
        }
    }

    func delete(_ exercise: ExerciseDTO) async -> Bool {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        do {
            try await training.deleteExercise(id: exercise.id)
            await load()
            return lastError == nil
        } catch {
            fail(error)
            return false
        }
    }

    private func fail(_ error: Error) {
        lastError = error.localizedDescription
        feedbackID = UUID()
    }
}

// MARK: - Plan structure

struct StaffExecutionNode: Identifiable, Hashable {
    let execution: ExerciseExecutionDTO
    var sets: [ExerciseSetDTO]

    var id: String { execution.id }
}

@MainActor
@Observable
final class StaffPlanModel {
    private(set) var plan: TrainingPlanDTO
    private(set) var sessions: [TrainingSessionDTO] = []
    private(set) var exercises: [ExerciseDTO] = []
    /// Structure of the session currently open in the editor.
    private(set) var nodes: [StaffExecutionNode] = []
    private(set) var isLoading = false
    private(set) var isWorking = false
    private(set) var lastError: String?
    private(set) var feedbackID = UUID()

    let trainerId: String
    private let training: TrainingService

    init(plan: TrainingPlanDTO, trainerId: String, api: AuthenticatedAPIClient) {
        self.plan = plan
        self.trainerId = trainerId
        self.training = TrainingService(api: api)
    }

    var exerciseNameById: [String: String] {
        Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    func load() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            async let planTask = training.getPlan(id: plan.id)
            async let sessionsTask = training.listSessions(forPlanId: plan.id)
            async let exercisesTask = training.listExercises()
            let (loadedPlan, loadedSessions, loadedExercises) = try await (planTask, sessionsTask, exercisesTask)
            if let loadedPlan { plan = loadedPlan }
            sessions = loadedSessions
            exercises = loadedExercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            fail(error)
        }
    }

    func updatePlan(_ request: TrainingPlanRequest) async -> Bool {
        await perform { [self] in
            plan = try await training.updatePlan(id: plan.id, request)
        }
    }

    func addSession() async -> Bool {
        await perform { [self] in
            _ = try await training.createSession(planId: plan.id)
            sessions = try await training.listSessions(forPlanId: plan.id)
        }
    }

    func deleteSession(_ session: TrainingSessionDTO) async -> Bool {
        await perform { [self] in
            try await training.deleteSession(id: session.id)
            sessions = try await training.listSessions(forPlanId: plan.id)
        }
    }

    // MARK: Session structure

    func loadSession(_ sessionId: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            try await reloadNodes(sessionId: sessionId)
        } catch {
            fail(error)
        }
    }

    func addExecution(exerciseId: String, sessionId: String, notes: String?) async -> Bool {
        await perform { [self] in
            _ = try await training.createExecution(
                CreateExerciseExecutionRequest(exerciseId: exerciseId, trainingSessionId: sessionId, notes: notes)
            )
            try await reloadNodes(sessionId: sessionId)
        }
    }

    func updateNotes(_ node: StaffExecutionNode, notes: String?, sessionId: String) async -> Bool {
        await perform { [self] in
            _ = try await training.updateExecution(id: node.execution.id, node.execution.updateRequest(notes: notes))
            try await reloadNodes(sessionId: sessionId)
        }
    }

    func deleteExecution(_ node: StaffExecutionNode, sessionId: String) async -> Bool {
        await perform { [self] in
            try await training.deleteExecution(id: node.execution.id)
            try await reloadNodes(sessionId: sessionId)
        }
    }

    func addSet(to node: StaffExecutionNode, reps: Int, sessionId: String) async -> Bool {
        await perform { [self] in
            _ = try await training.createSet(CreateExerciseSetRequest(exerciseExecutionId: node.execution.id, reps: reps))
            try await reloadNodes(sessionId: sessionId)
        }
    }

    func updateSet(_ set: ExerciseSetDTO, reps: Int, sessionId: String) async -> Bool {
        await perform { [self] in
            _ = try await training.updateSet(
                id: set.id,
                CreateExerciseSetRequest(exerciseExecutionId: set.exerciseExecutionId, reps: reps)
            )
            try await reloadNodes(sessionId: sessionId)
        }
    }

    func deleteSet(_ set: ExerciseSetDTO, sessionId: String) async -> Bool {
        await perform { [self] in
            try await training.deleteSet(id: set.id)
            try await reloadNodes(sessionId: sessionId)
        }
    }

    // MARK: Helpers

    private func reloadNodes(sessionId: String) async throws {
        let executions = try await training.listExecutions(forSessionId: sessionId)
        var loaded: [StaffExecutionNode] = []
        for execution in executions {
            let sets = try await training.listSets(forExecutionId: execution.id)
            loaded.append(StaffExecutionNode(execution: execution, sets: sets))
        }
        nodes = loaded
    }

    /// Runs a write, reporting any failure through `lastError`; returns `true` on success.
    private func perform(_ work: () async throws -> Void) async -> Bool {
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        do {
            try await work()
            return true
        } catch {
            fail(error)
            return false
        }
    }

    private func fail(_ error: Error) {
        lastError = error.localizedDescription
        feedbackID = UUID()
    }
}
