//
//  EnvFileEditorView.swift
//  Devtail
//
//  The editable surface for .env-family files — the first write path in
//  the workspace file viewer. Wraps a plain SwiftUI TextEditor, an explicit
//  Save action (button + Cmd+S), and mtime-conflict handling around
//  EnvFileSaver. Everything else in the viewer stays read-only.
//
//  Draft state (text, loaded snapshot, recorded mtime) lives on
//  `session.envDrafts`, NOT view-local `@State` — `FileViewerTabView` (and
//  this view with it) unmounts when its tab isn't selected, so view-local
//  state would silently lose edits on every tab switch. On (re)mount this
//  view reuses the existing session draft when present instead of reloading
//  from disk; that reuse is what makes edits survive.
//

import SwiftUI

struct EnvFileEditorView: View {
    let path: String
    let loadedText: String
    let loadedModificationDate: Date?
    let session: WorkspaceSession

    @State private var saveError: String?
    @State private var showConflictAlert = false

    private var text: String {
        session.draft(for: path)?.text ?? loadedText
    }

    private var isDirty: Bool { session.isDirty(path: path) }

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

            TextEditor(text: Binding(
                get: { text },
                set: { session.updateDraft(text: $0, for: path) }
            ))
            .font(DevtailTokens.Typography.mono)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            session.createDraftIfNeeded(for: path, loadedText: loadedText, recordedModificationDate: loadedModificationDate)
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
    private func save() {
        saveError = nil
        let recordedModificationDate = session.draft(for: path)?.recordedModificationDate
        if let recordedModificationDate, EnvFileSaver.hasConflict(path: path, recordedModificationDate: recordedModificationDate) {
            showConflictAlert = true
            return
        }
        performSave()
    }

    /// User explicitly chose "Overwrite" in the conflict alert — skip the
    /// conflict check this one time and write anyway.
    private func forceSave() {
        performSave()
    }

    private func performSave() {
        do {
            try EnvFileSaver.save(text: text, to: path)
            let newModificationDate = EnvFileSaver.modificationDate(at: path)
            session.setDraft(
                EnvDraft(text: text, loadedText: text, recordedModificationDate: newModificationDate),
                for: path
            )
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// User explicitly chose "Reload" in the conflict alert — discards
    /// local edits and re-reads the file from disk.
    private func reload() {
        guard case .text(let freshText, _, _) = FileContentLoader.load(path: path) else { return }
        session.setDraft(
            EnvDraft(text: freshText, loadedText: freshText, recordedModificationDate: EnvFileSaver.modificationDate(at: path)),
            for: path
        )
    }
}
