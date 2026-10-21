//
//  StaffPlanViews.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

// MARK: - Plan form

struct StaffPlanFormSheet: View {
    let title: String
    let plan: TrainingPlanDTO?
    /// Returns `true` when the plan was persisted and the sheet can close.
    let onSave: (_ name: String, _ description: String?, _ days: Int, _ start: Date?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var days: Int
    @State private var hasStart: Bool
    @State private var startDate: Date
    @State private var isSaving = false

    init(
        title: String,
        plan: TrainingPlanDTO?,
        onSave: @escaping (_ name: String, _ description: String?, _ days: Int, _ start: Date?) async -> Bool
    ) {
        self.title = title
        self.plan = plan
        self.onSave = onSave
        _name = State(initialValue: plan?.name ?? "")
        _description = State(initialValue: plan?.description ?? "")
        _days = State(initialValue: plan?.durationDays ?? 30)
        _hasStart = State(initialValue: plan?.startDate != nil)
        _startDate = State(initialValue: plan?.startDate ?? Date())
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && days > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Duración") {
                    Stepper("\(days) días", value: $days, in: 1...365)
                    Toggle("Fecha de inicio", isOn: $hasStart)
                    if hasStart {
                        DatePicker("Inicio", selection: $startDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
                            let saved = await onSave(
                                name.trimmingCharacters(in: .whitespacesAndNewlines),
                                trimmed.isEmpty ? nil : trimmed,
                                days,
                                hasStart ? startDate : nil
                            )
                            if saved { dismiss() }
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .overlay { if isSaving { ProgressView() } }
        }
        .interactiveDismissDisabled(isSaving)
    }
}

// MARK: - Plan detail

struct StaffPlanView: View {
    @Bindable var session: GymSessionModel
    let plan: TrainingPlanDTO
    let memberId: String

    @State private var model: StaffPlanModel?
    @State private var showEdit = false
    @State private var sessionPendingDelete: TrainingSessionDTO?
    @State private var toast: Toast?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(model?.plan.name ?? plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let created = StaffPlanModel(plan: plan, trainerId: session.userId, api: session.session.apiClient)
                model = created
                await created.load()
            }
        }
        .toast($toast)
    }

    @ViewBuilder
    private func content(_ model: StaffPlanModel) -> some View {
        List {
            Section("Plan") {
                if let description = model.plan.description, !description.isEmpty {
                    Text(description)
                }
                if !model.plan.durationLabel.isEmpty {
                    LabeledContent("Duración", value: model.plan.durationLabel)
                }
                if let start = model.plan.startDate {
                    LabeledContent("Inicio", value: start.formatted(date: .abbreviated, time: .omitted))
                }
                if let end = model.plan.endDate {
                    LabeledContent("Fin", value: end.formatted(date: .abbreviated, time: .omitted))
                }
            }

            Section("Sesiones") {
                if model.isLoading && model.sessions.isEmpty {
                    ProgressView()
                } else if model.sessions.isEmpty {
                    Text("El plan todavía no tiene sesiones")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.sessions.enumerated()), id: \.element.id) { index, trainingSession in
                        NavigationLink {
                            StaffSessionEditorView(model: model, trainingSession: trainingSession, number: index + 1)
                        } label: {
                            Label("Sesión \(index + 1)", systemImage: "list.bullet.rectangle")
                        }
                        .swipeActions {
                            Button("Eliminar", role: .destructive) { sessionPendingDelete = trainingSession }
                        }
                    }
                }
                Button {
                    Task {
                        if await model.addSession() { toast = .success("Sesión agregada") }
                    }
                } label: {
                    Label("Agregar sesión", systemImage: "plus")
                }
                .disabled(model.isWorking)
            }
        }
        .refreshable { await model.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { showEdit = true }
            }
        }
        .onChange(of: model.feedbackID) {
            if let error = model.lastError { toast = .error(error) }
        }
        .sheet(isPresented: $showEdit) {
            StaffPlanFormSheet(title: "Editar plan", plan: model.plan) { name, description, days, start in
                let request = TrainingPlanRequest(
                    memberId: model.plan.memberId,
                    trainerId: model.plan.trainerId ?? model.trainerId,
                    name: name,
                    description: description,
                    durationDays: days,
                    startDate: start,
                    endDate: start.flatMap { Calendar.current.date(byAdding: .day, value: days, to: $0) }
                )
                let saved = await model.updatePlan(request)
                if saved { toast = .success("Plan actualizado") }
                return saved
            }
        }
        .confirmationDialog(
            "¿Eliminar sesión?",
            isPresented: Binding(
                get: { sessionPendingDelete != nil },
                set: { if !$0 { sessionPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: sessionPendingDelete
        ) { trainingSession in
            Button("Eliminar sesión", role: .destructive) {
                Task {
                    if await model.deleteSession(trainingSession) { toast = .success("Sesión eliminada") }
                }
            }
            Button("Volver", role: .cancel) {}
        } message: { _ in
            Text("Si la sesión tiene ejercicios, el backend puede rechazar el borrado.")
        }
    }
}

// MARK: - Session editor

private enum SessionSheet: Identifiable {
    case addExercise
    case addSet(StaffExecutionNode)
    case editSet(ExerciseSetDTO)
    case editNotes(StaffExecutionNode)

    var id: String {
        switch self {
        case .addExercise: "add-exercise"
        case .addSet(let node): "add-set-\(node.id)"
        case .editSet(let set): "edit-set-\(set.id)"
        case .editNotes(let node): "notes-\(node.id)"
        }
    }
}

struct StaffSessionEditorView: View {
    let model: StaffPlanModel
    let trainingSession: TrainingSessionDTO
    let number: Int

    @State private var sheet: SessionSheet?
    @State private var executionPendingDelete: StaffExecutionNode?
    @State private var toast: Toast?

    var body: some View {
        List {
            if model.isLoading && model.nodes.isEmpty {
                ProgressView()
            } else if model.nodes.isEmpty {
                ContentUnavailableView(
                    "Sesión vacía",
                    systemImage: "dumbbell",
                    description: Text("Agregá un ejercicio para armar la sesión.")
                )
            }

            ForEach(model.nodes) { node in
                Section {
                    ForEach(Array(node.sets.enumerated()), id: \.element.id) { index, set in
                        Button {
                            sheet = .editSet(set)
                        } label: {
                            HStack {
                                Text("Serie \(index + 1)")
                                Spacer()
                                Text("\(set.reps) reps")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                        .swipeActions {
                            Button("Eliminar", role: .destructive) {
                                Task {
                                    if await model.deleteSet(set, sessionId: trainingSession.id) {
                                        toast = .success("Serie eliminada")
                                    }
                                }
                            }
                        }
                    }
                    Button {
                        sheet = .addSet(node)
                    } label: {
                        Label("Agregar serie", systemImage: "plus")
                    }
                    if let notes = node.execution.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text(model.exerciseNameById[node.execution.exerciseId] ?? "Ejercicio")
                        Spacer()
                        Menu {
                            Button("Editar notas", systemImage: "note.text") { sheet = .editNotes(node) }
                            Button("Quitar ejercicio", systemImage: "trash", role: .destructive) {
                                executionPendingDelete = node
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle("Sesión \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadSession(trainingSession.id) }
        .refreshable { await model.loadSession(trainingSession.id) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Agregar ejercicio", systemImage: "plus") { sheet = .addExercise }
            }
        }
        .onChange(of: model.feedbackID) {
            if let error = model.lastError { toast = .error(error) }
        }
        .toast($toast)
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
        }
        .confirmationDialog(
            "¿Quitar ejercicio?",
            isPresented: Binding(
                get: { executionPendingDelete != nil },
                set: { if !$0 { executionPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: executionPendingDelete
        ) { node in
            Button("Quitar ejercicio", role: .destructive) {
                Task {
                    if await model.deleteExecution(node, sessionId: trainingSession.id) {
                        toast = .success("Ejercicio quitado")
                    }
                }
            }
            Button("Volver", role: .cancel) {}
        } message: { _ in
            Text("También se pierden sus series. Si el cliente ya lo completó, el backend puede rechazarlo.")
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: SessionSheet) -> some View {
        switch sheet {
        case .addExercise:
            StaffExercisePickerSheet(exercises: model.exercises) { exercise, notes in
                let added = await model.addExecution(
                    exerciseId: exercise.id,
                    sessionId: trainingSession.id,
                    notes: notes
                )
                if added { toast = .success("Ejercicio agregado") }
                return added
            }
        case .addSet(let node):
            StaffRepsSheet(title: "Nueva serie", initialReps: node.sets.last?.reps ?? 10) { reps in
                let added = await model.addSet(to: node, reps: reps, sessionId: trainingSession.id)
                if added { toast = .success("Serie agregada") }
                return added
            }
        case .editSet(let set):
            StaffRepsSheet(title: "Editar serie", initialReps: set.reps) { reps in
                let saved = await model.updateSet(set, reps: reps, sessionId: trainingSession.id)
                if saved { toast = .success("Serie actualizada") }
                return saved
            }
        case .editNotes(let node):
            StaffNotesSheet(initialNotes: node.execution.notes ?? "") { notes in
                let saved = await model.updateNotes(node, notes: notes, sessionId: trainingSession.id)
                if saved { toast = .success("Notas actualizadas") }
                return saved
            }
        }
    }
}

// MARK: - Sheets

private struct StaffExercisePickerSheet: View {
    let exercises: [ExerciseDTO]
    let onPick: (_ exercise: ExerciseDTO, _ notes: String?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selected: ExerciseDTO?
    @State private var notes = ""
    @State private var isSaving = false

    private var filtered: [ExerciseDTO] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "Sin ejercicios",
                        systemImage: "dumbbell",
                        description: Text("Creá ejercicios en la pestaña Ejercicios.")
                    )
                } else {
                    Section {
                        ForEach(filtered) { exercise in
                            Button {
                                selected = exercise
                            } label: {
                                HStack(spacing: 12) {
                                    ExerciseThumbnail(urlString: exercise.photoUrl, size: 36)
                                    Text(exercise.name)
                                    Spacer()
                                    if selected == exercise {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    Section("Notas (opcional)") {
                        TextField("Notas", text: $notes, axis: .vertical)
                            .lineLimit(1...3)
                    }
                }
            }
            .searchable(text: $search, prompt: "Buscar ejercicio")
            .navigationTitle("Agregar ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") {
                        guard let selected else { return }
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            if await onPick(selected, trimmed.isEmpty ? nil : trimmed) { dismiss() }
                        }
                    }
                    .disabled(selected == nil || isSaving)
                }
            }
            .overlay { if isSaving { ProgressView() } }
        }
        .interactiveDismissDisabled(isSaving)
    }
}

private struct StaffRepsSheet: View {
    let title: String
    let initialReps: Int
    let onSave: (_ reps: Int) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var reps: Int
    @State private var isSaving = false

    init(title: String, initialReps: Int, onSave: @escaping (_ reps: Int) async -> Bool) {
        self.title = title
        self.initialReps = initialReps
        self.onSave = onSave
        _reps = State(initialValue: max(initialReps, 1))
    }

    var body: some View {
        NavigationStack {
            Form {
                Stepper("\(reps) repeticiones", value: $reps, in: 1...200)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            if await onSave(reps) { dismiss() }
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .overlay { if isSaving { ProgressView() } }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isSaving)
    }
}

private struct StaffNotesSheet: View {
    let initialNotes: String
    let onSave: (_ notes: String?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var notes: String
    @State private var isSaving = false

    init(initialNotes: String, onSave: @escaping (_ notes: String?) async -> Bool) {
        self.initialNotes = initialNotes
        self.onSave = onSave
        _notes = State(initialValue: initialNotes)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Notas", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle("Notas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            if await onSave(trimmed.isEmpty ? nil : trimmed) { dismiss() }
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .overlay { if isSaving { ProgressView() } }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isSaving)
    }
}
