//
//  EnvFileEditorView.swift
//  Devtail
//
//  The editable surface for .env-family files — the first write path in
//  the workspace file viewer. Wraps a plain SwiftUI TextEditor, an explicit
//  Save action (button + Cmd+S), and mtime-conflict handling around
//  EnvFileSaver. Everything else in the viewer stays read-only.
//

import SwiftUI

struct EnvFileEditorView: View {
    let path: String
    let session: WorkspaceSession

    @State private var text: String
    /// The last text known to match disk — updated after a successful save
    /// or reload. Dirty = `text != savedText`. Starts as the text loaded by
    /// `FileViewerTabView`.
    @State private var savedText: String
    @State private var recordedModificationDate: Date?
    @State private var saveError: String?
    @State private var showConflictAlert = false

    init(path: String, loadedText: String, loadedModificationDate: Date?, session: WorkspaceSession) {
        self.path = path
        self.session = session
        _text = State(initialValue: loadedText)
        _savedText = State(initialValue: loadedText)
        _recordedModificationDate = State(initialValue: loadedModificationDate)
    }

    private var isDirty: Bool { text != savedText }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let saveError {
                    Text(saveError)
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Save") { save() }
                    .disabled(!isDirty)
                    .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
            .padding(.vertical, DevtailTokens.Spacing.gapSmall)

            TextEditor(text: $text)
                .font(DevtailTokens.Typography.mono)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: text) { _, newValue in
            session.setDirty(newValue != savedText, path: path)
        }
        .onAppear {
            session.pendingEnvSave = { completion in
                save(then: completion)
            }
        }
        .onDisappear {
            session.pendingEnvSave = nil
        }
        .alert("File changed on disk", isPresented: $showConflictAlert) {
            Button("Overwrite") { forceSave() }
            Button("Reload") { reload() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This file was modified outside Devtail since it was opened. Overwrite the changes on disk, or reload to discard your local edits.")
        }
    }

    /// Explicit save entry point (button + Cmd+S). Checks the on-disk
    /// modification date against the one recorded at load/last-save time
    /// first — a mismatch means an external edit happened, so we ask before
    /// overwriting rather than clobbering it silently.
    private func save(then completion: ((Bool) -> Void)? = nil) {
        saveError = nil
        if let recordedModificationDate, EnvFileSaver.hasConflict(path: path, recordedModificationDate: recordedModificationDate) {
            showConflictAlert = true
            completion?(false)
            return
        }
        performSave(then: completion)
    }

    /// User explicitly chose "Overwrite" in the conflict alert — skip the
    /// conflict check this one time and write anyway.
    private func forceSave() {
        performSave()
    }

    private func performSave(then completion: ((Bool) -> Void)? = nil) {
        do {
            try EnvFileSaver.save(text: text, to: path)
            savedText = text
            recordedModificationDate = EnvFileSaver.modificationDate(at: path)
            session.setDirty(false, path: path)
            completion?(true)
        } catch {
            saveError = error.localizedDescription
            completion?(false)
        }
    }

    /// User explicitly chose "Reload" in the conflict alert — discards
    /// local edits and re-reads the file from disk.
    private func reload() {
        if case .text(let freshText, _, _) = FileContentLoader.load(path: path) {
            text = freshText
            savedText = freshText
        }
        recordedModificationDate = EnvFileSaver.modificationDate(at: path)
        session.setDirty(false, path: path)
    }
}
