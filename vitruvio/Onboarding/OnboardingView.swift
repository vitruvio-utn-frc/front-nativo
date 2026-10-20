//
//  OnboardingView.swift
//  vitruvio
//

import SwiftUI
import VitruvioCore

struct OnboardingView: View {
    @Bindable var gate: AppGateModel
    @State private var form: OnboardingFormState

    init(gate: AppGateModel, prefill: ProfilePrefill) {
        self.gate = gate
        _form = State(initialValue: OnboardingFormState(prefill: prefill))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identidad") {
                    TextField("DNI", text: $form.idNumber)
                        .keyboardType(.numberPad)
                    TextField("Nombre", text: $form.firstName)
                    TextField("Apellido", text: $form.lastName)
                    TextField("Email", text: $form.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Perfil") {
                    TextField("Altura (cm)", text: $form.height)
                        .keyboardType(.decimalPad)
                    TextField("Peso (kg)", text: $form.weight)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha de nacimiento", selection: $form.birthDate, displayedComponents: .date)
                    Picker("Género", selection: $form.genderId) {
                        Text("Seleccionar").tag("")
                        ForEach(gate.genders) { gender in
                            Text(gender.name).tag(gender.id)
                        }
                    }
                }

                if let local = form.validationMessage {
                    Section {
                        Text(local)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if let error = gate.lastError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button("Crear perfil") {
                        Task { await gate.submit(form: form) }
                    }
                    .disabled(gate.isBusy || form.validationMessage != nil)

                    Button("Cerrar sesión", role: .destructive) {
                        Task { await gate.session.logout() }
                    }
                }
            }
            .navigationTitle("Completar perfil")
            .overlay {
                if gate.isBusy {
                    ProgressView()
                }
            }
            .task {
                await gate.loadGendersIfNeeded()
            }
        }
    }
}
