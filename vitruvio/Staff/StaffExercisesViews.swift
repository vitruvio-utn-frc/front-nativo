//
//  StaffExercisesViews.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

private enum ExerciseSheet: Identifiable {
    case create
    case edit(ExerciseDTO)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let exercise): "edit-\(exercise.id)"
        }
    }
}

struct StaffExercisesHomeView: View {
    @Bindable var session: GymSessionModel
    @State private var model: StaffExercisesModel?
    @State private var search = ""
    @State private var sheet: ExerciseSheet?
    @State private var pendingDelete: ExerciseDTO?
    @State private var toast: Toast?

    var body: some View {
        Group {
            if let model {
                list(model)
            } else {
                ProgressView("Cargando ejercicios…")
            }
        }
        .task {
            if model == nil {
                let created = StaffExercisesModel(api: session.session.apiClient)
                model = created
                await created.load()
            }
        }
        .toast($toast)
    }

    @ViewBuilder
    private func list(_ model: StaffExercisesModel) -> some View {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = query.isEmpty
            ? model.exercises
            : model.exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
        List {
            if model.isLoading && model.exercises.isEmpty {
                ProgressView()
            } else if model.exercises.isEmpty {
                ContentUnavailableView(
                    "Sin ejercicios",
                    systemImage: "dumbbell",
                    description: Text("Tocá + para crear el primero.")
                )
            } else if visible.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ForEach(visible) { exercise in
                    Button {
                        sheet = .edit(exercise)
                    } label: {
                        HStack(spacing: 12) {
                            ExerciseThumbnail(urlString: exercise.photoUrl)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                Text(subtitle(for: exercise, model: model))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeActions {
                        Button("Eliminar", role: .destructive) { pendingDelete = exercise }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Buscar ejercicio")
        .refreshable { await model.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nuevo ejercicio", systemImage: "plus") { sheet = .create }
            }
        }
        .onChange(of: model.feedbackID) {
            if let error = model.lastError { toast = .error(error) }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .create:
                StaffExerciseFormSheet(model: model, exercise: nil) {
                    toast = .success("Ejercicio creado")
                }
            case .edit(let exercise):
                StaffExerciseFormSheet(model: model, exercise: exercise) {
                    toast = .success("Ejercicio actualizado")
                }
            }
        }
        .confirmationDialog(
            "¿Eliminar ejercicio?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { exercise in
            Button("Eliminar “\(exercise.name)”", role: .destructive) {
                Task {
                    if await model.delete(exercise) { toast = .success("Ejercicio eliminado") }
                }
            }
            Button("Volver", role: .cancel) {}
        } message: { _ in
            Text("Si algún plan usa este ejercicio, el backend puede rechazar el borrado.")
        }
    }

    private func subtitle(for exercise: ExerciseDTO, model: StaffExercisesModel) -> String {
        var parts: [String] = []
        if let typeId = exercise.exerciseTypeId, let name = model.exerciseTypeNameById[typeId] {
            parts.append(name)
        }
        if let machineId = exercise.machineTypeId, let name = model.machineTypeNameById[machineId] {
            parts.append(name)
        }
        return parts.isEmpty ? "Sin clasificar" : parts.joined(separator: " · ")
    }
}

private struct StaffExerciseFormSheet: View {
    let model: StaffExercisesModel
    let exercise: ExerciseDTO?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var exerciseTypeId: Int?
    @State private var machineTypeId: Int?
    @State private var calories: String
    @State private var photoUrl: String
    @State private var videoUrl: String
    @State private var errorToast: Toast?

    init(model: StaffExercisesModel, exercise: ExerciseDTO?, onSaved: @escaping () -> Void) {
        self.model = model
        self.exercise = exercise
        self.onSaved = onSaved
        _name = State(initialValue: exercise?.name ?? "")
        _description = State(initialValue: exercise?.description ?? "")
        _exerciseTypeId = State(initialValue: exercise?.exerciseTypeId)
        _machineTypeId = State(initialValue: exercise?.machineTypeId)
        _calories = State(initialValue: exercise?.caloriesBurnRate.map { $0.formatted(.number.grouping(.never)) } ?? "")
        _photoUrl = State(initialValue: exercise?.photoUrl ?? "")
        _videoUrl = State(initialValue: exercise?.videoUrl ?? "")
    }

    private var parsedCalories: Double? {
        Double(calories.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && exerciseTypeId != nil
            && (parsedCalories ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ejercicio") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Clasificación") {
                    Picker("Tipo", selection: $exerciseTypeId) {
                        Text("Seleccionar").tag(Int?.none)
                        ForEach(model.exerciseTypes) { type in
                            Text(type.name).tag(Int?.some(type.id))
                        }
                    }
                    Picker("Máquina", selection: $machineTypeId) {
                        Text("Ninguna").tag(Int?.none)
                        ForEach(model.machineTypes) { type in
                            Text(type.name).tag(Int?.some(type.id))
                        }
                    }
                    LabeledContent("Kcal por repetición") {
                        TextField("0", text: $calories)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Multimedia (opcional)") {
                    TextField("URL de foto", text: $photoUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("URL de video", text: $videoUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(exercise == nil ? "Nuevo ejercicio" : "Editar ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(!canSave || model.isWorking)
                }
            }
            .overlay { if model.isWorking { ProgressView() } }
            .onChange(of: model.feedbackID) {
                if let error = model.lastError { errorToast = .error(error) }
            }
            .toast($errorToast)
        }
        .interactiveDismissDisabled(model.isWorking)
    }

    private func save() async {
        guard let exerciseTypeId, let calories = parsedCalories else { return }
        func optional(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        let request = ExerciseRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: optional(description),
            exerciseTypeId: exerciseTypeId,
            machineTypeId: machineTypeId,
            photoUrl: optional(photoUrl),
            videoUrl: optional(videoUrl),
            caloriesBurnRate: calories
        )
        if await model.save(id: exercise?.id, request) {
            onSaved()
            dismiss()
        }
    }
}
