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
                Section("Identity") {
                    TextField("ID number", text: $form.idNumber)
                        .keyboardType(.numberPad)
                    TextField("First name", text: $form.firstName)
                    TextField("Last name", text: $form.lastName)
                    TextField("Email", text: $form.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Profile") {
                    TextField("Height (cm)", text: $form.height)
                        .keyboardType(.decimalPad)
                    TextField("Weight (kg)", text: $form.weight)
                        .keyboardType(.decimalPad)
                    DatePicker("Birth date", selection: $form.birthDate, displayedComponents: .date)
                    Picker("Gender", selection: $form.genderId) {
                        Text("Select").tag("")
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
                    Button("Create profile") {
                        Task { await gate.submit(form: form) }
                    }
                    .disabled(gate.isBusy || form.validationMessage != nil)

                    Button("Sign out", role: .destructive) {
                        Task { await gate.session.logout() }
                    }
                }
            }
            .navigationTitle("Complete profile")
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
