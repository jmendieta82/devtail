//
//  NewProjectView.swift
//  Devtail
//
//  Form presented in a dedicated Window scene to create a new Project.
//  Reads the shared ProjectStore via @Environment and dismisses itself
//  on success through @Environment(\.dismissWindow).
//

import SwiftUI
import SwiftData

struct NewProjectView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var showError: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if showError {
                    Text(store.lastError?.localizedDescription ?? "Unknown error")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("Cancel") {
                    resetState()
                    dismissWindow(id: WindowID.newProject)
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createAction()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedName.isEmpty)
            }
        }
        .padding()
        .frame(width: 360, height: 280)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createAction() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        store.createProject(
            name: trimmedName,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )

        if store.lastError == nil {
            resetState()
            dismissWindow(id: WindowID.newProject)
        } else {
            showError = true
        }
    }

    private func resetState() {
        name = ""
        notes = ""
        showError = false
    }
}

#Preview {
    let container = PersistenceController.makeContainer(inMemory: true)
    let repository = ProjectRepository(context: container.mainContext)
    let store = ProjectStore(repository: repository)
    NewProjectView()
        .environment(store)
}
