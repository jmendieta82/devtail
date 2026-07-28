//
//  TaskBoardTabView.swift
//  Devtail
//
//  Trello-style task board over .devtail/tasks.md, mounted as a full-width
//  closable tab (mirrors the Settings tab mount pattern in
//  WorkspaceRootView: conditional ZStack member, no PTY to preserve). The
//  three columns render side by side, one per TaskState — column = state
//  = source of truth, same contract as the side-panel board it replaces.
//
//  Each task renders as a card from the ProcessCardView/dashboard family
//  (Radius.card surface, subtle fill and stroke) with a kanban-style
//  state spine on the leading edge; the spine and the column dots share
//  one state-color mapping (Doing = accent, Pending = yellow, Done =
//  green) so state reads at a glance without labels. Refreshes on appear
//  so agent-written items show up when the tab opens.
//

import SwiftUI

struct TaskBoardTabView: View {
    let session: WorkspaceSession

    /// Task currently in inline title editing (double-click or menu Edit),
    /// with its draft text. Nil when nothing is being edited.
    @State private var editingTaskID: UUID?
    @State private var editingTitle = ""
    @FocusState private var editingFieldFocused: Bool
    /// Column currently hovered by a card drag — drives the drop highlight.
    @State private var dropTargetState: TaskState?

    private var store: TaskBoardStore { session.taskBoard }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(DevtailTokens.Spacing.cardPadding)
            if store.board != nil {
                board
            } else if !store.fileExists {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { store.refresh() }
    }

    private var header: some View {
        HStack {
            SectionHeader(title: "Tasks")
            Spacer()
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
            }
            .buttonStyle(.icon)
            .foregroundStyle(.secondary)
            .help("Reload the board from disk")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            Text("No task board yet")
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Button("Create task board") {
                store.createBoard()
            }
            .font(DevtailTokens.Typography.caption)
        }
    }

    private var board: some View {
        HStack(alignment: .top, spacing: DevtailTokens.Spacing.gapMedium) {
            ForEach(TaskState.allCases, id: \.self) { state in
                column(state, tasks: store.board?.tasks(in: state) ?? [])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, DevtailTokens.Spacing.cardPadding)
        .padding(.bottom, DevtailTokens.Spacing.cardPadding)
    }

    private func column(_ state: TaskState, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
            columnHeader(state, tasks: tasks)
            ScrollView {
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                    if tasks.isEmpty {
                        emptyColumnPlaceholder
                    } else {
                        ForEach(tasks) { task in
                            taskCard(task)
                        }
                    }
                }
            }
            quickAddField(for: state)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        // Whole-column drop target: a card dragged from another column
        // lands at the end of this one (same semantics as the move menu).
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .fill(Self.stateColor(state).opacity(dropTargetState == state ? 0.08 : 0))
        )
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            store.moveTask(id: id, to: state)
            return true
        } isTargeted: { targeted in
            dropTargetState = targeted ? state : (dropTargetState == state ? nil : dropTargetState)
        }
    }

    private func columnHeader(_ state: TaskState, tasks: [TaskItem]) -> some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            Circle()
                .fill(Self.stateColor(state))
                .frame(width: 7, height: 7)
            Text("\(state.displayName) \u{00B7} \(tasks.count)")
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
                .textCase(.uppercase)
            Spacer()
            if state == .done && !tasks.isEmpty {
                Button {
                    store.archiveDone(on: Date())
                } label: {
                    Image(systemName: "archivebox")
                        .font(.system(size: 10))
                }
                .buttonStyle(.icon)
                .foregroundStyle(.secondary)
                .help("Move done tasks to tasks-archive.md")
            }
        }
    }

    private var emptyColumnPlaceholder: some View {
        Text("Empty")
            .font(DevtailTokens.Typography.captionSmall)
            .foregroundStyle(DevtailTokens.Colors.textTertiary.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DevtailTokens.Spacing.gapSmall)
            .padding(.horizontal, DevtailTokens.Spacing.gapMedium)
            .overlay(
                RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                    .strokeBorder(DevtailTokens.Colors.borderSubtle,
                                  style: StrokeStyle(lineWidth: DevtailTokens.BorderWidth.default, dash: [4, 3]))
            )
    }

    private func taskCard(_ task: TaskItem) -> some View {
        // firstTextBaseline keeps the checkbox and menu pinned to the
        // FIRST line when a long title wraps the card taller.
        HStack(alignment: .firstTextBaseline, spacing: DevtailTokens.Spacing.gapSmall) {
            Button {
                store.moveTask(id: task.id, to: task.state == .done ? .pending : .done)
            } label: {
                Image(systemName: task.state == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(task.state == .done
                        ? DevtailTokens.Colors.trafficGreen
                        : DevtailTokens.Colors.textTertiary)
            }
            .buttonStyle(.icon)
            .help(task.state == .done ? "Reopen (back to Pending)" : "Mark done")

            if let priority = task.priority {
                Image(systemName: "flag.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Self.priorityColor(priority))
                    .help("Priority: \(priority.displayName)")
            }

            if editingTaskID == task.id {
                // axis: .vertical so long titles edit as wrapped text
                // instead of a scrolling single line.
                TextField("Task title", text: $editingTitle, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DevtailTokens.Typography.caption)
                    .focused($editingFieldFocused)
                    .onSubmit { commitRename(task) }
                    .onExitCommand { cancelRename() }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(task.state == .done
                            ? DevtailTokens.Colors.textTertiary
                            : DevtailTokens.Colors.textSecondary)
                        .strikethrough(task.state == .done)
                        // No line limit — the card grows to show the whole
                        // annotation. fixedSize(vertical) is what makes Text
                        // WRAP here instead of truncating to one line inside
                        // the HStack.
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture(count: 2) { beginRename(task) }
                    if let createdDate = task.createdDate {
                        Text(createdDate)
                            .font(DevtailTokens.Typography.captionSmall)
                            .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            Menu {
                Button("Edit") { beginRename(task) }
                let liveAgents = session.liveAgents
                if liveAgents.count == 1 {
                    Button("Send to agent") {
                        session.sendTask(title: task.title, toAgent: liveAgents[0].id)
                    }
                } else if liveAgents.count > 1 {
                    Menu("Send to") {
                        ForEach(liveAgents) { agent in
                            Button(agent.title) {
                                session.sendTask(title: task.title, toAgent: agent.id)
                            }
                        }
                    }
                }
                Divider()
                ForEach(TaskState.allCases.filter { $0 != task.state }, id: \.self) { target in
                    Button("Move to \(target.displayName)") {
                        store.moveTask(id: task.id, to: target)
                    }
                }
                Divider()
                Menu("Priority") {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Button(priority.displayName) {
                            store.setTaskPriority(id: task.id, to: priority)
                        }
                    }
                    if task.priority != nil {
                        Divider()
                        Button("Clear priority") {
                            store.setTaskPriority(id: task.id, to: nil)
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10))
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, DevtailTokens.Spacing.gapSmall + 2)
        .padding(.leading, DevtailTokens.Spacing.gapMedium)
        .padding(.trailing, DevtailTokens.Spacing.gapSmall)
        .background(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DevtailTokens.Radius.card)
                .stroke(DevtailTokens.Colors.borderSubtle,
                        lineWidth: DevtailTokens.BorderWidth.default)
        )
        .overlay(alignment: .leading) {
            // Kanban state spine: rounded color edge inset from the card's
            // corners, the one at-a-glance state signal on the card itself.
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Self.stateColor(task.state).opacity(task.state == .done ? 0.45 : 0.9))
                .frame(width: 3)
                .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        }
        .opacity(task.state == .done ? 0.75 : 1)
        // The card travels as its task id; the drop side parses it back.
        // String payload keeps TaskItem free of Transferable/Codable
        // conformances it does not otherwise need.
        .draggable(task.id.uuidString)
    }

    /// One state-color mapping shared by the column dots and the card
    /// spines — Doing carries the app accent (it is "what is active now"),
    /// Pending/Done reuse the traffic palette.
    private static func stateColor(_ state: TaskState) -> Color {
        switch state {
        case .doing: DevtailTokens.Colors.accentPrimary
        case .pending: DevtailTokens.Colors.trafficYellow
        case .done: DevtailTokens.Colors.trafficGreen
        }
    }

    /// Flag color per priority — high uses the traffic red (most urgent),
    /// medium the traffic yellow, low a muted tertiary tone.
    private static func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: DevtailTokens.Colors.trafficRed
        case .medium: DevtailTokens.Colors.trafficYellow
        case .low: DevtailTokens.Colors.textTertiary
        }
    }

    /// Per-column quick-add: pinned under that column's cards, adds
    /// straight into that column's state.
    private func quickAddField(for state: TaskState) -> some View {
        QuickAddField(state: state) { title in
            store.addTask(title: title, to: state)
        }
    }

    // MARK: - Inline rename

    private func beginRename(_ task: TaskItem) {
        editingTitle = task.title
        editingTaskID = task.id
        editingFieldFocused = true
    }

    /// Empty (post-trim) input cancels instead of renaming to nothing —
    /// a task with no title would render as an unusable blank card.
    private func commitRename(_ task: TaskItem) {
        defer { cancelRename() }
        let title = editingTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, title != task.title else { return }
        store.renameTask(id: task.id, to: title)
    }

    private func cancelRename() {
        editingTaskID = nil
        editingTitle = ""
    }
}

/// Quick-add field for one board column — owns its own draft text so
/// typing in one column never touches another's field.
private struct QuickAddField: View {
    let state: TaskState
    let onAdd: (String) -> Void

    @State private var title = ""

    var body: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            TextField("Add a task", text: $title)
                .textFieldStyle(.plain)
                .font(DevtailTokens.Typography.caption)
                .onSubmit(submit)
            Button(action: submit) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.icon)
            .foregroundStyle(.secondary)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .help("Add to \(state.displayName)")
        }
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        title = ""
    }
}
