//
//  TaskBoardPanel.swift
//  Devtail
//
//  Side-panel task board over .devtail/tasks.md: three state groups,
//  checkbox toggling (Done vs Pending), a move menu per task, archive
//  for the Done group, and quick-add into Pending. Refreshes on appear
//  so agent-written items show up when the panel opens.
//
//  Each task renders as a card from the ProcessCardView/dashboard family
//  (Radius.card surface, subtle fill and stroke) with a kanban-style
//  state spine on the leading edge; the spine and the section dots share
//  one state-color mapping (Doing = accent, Pending = yellow, Done =
//  green) so state reads at a glance without labels.
//

import SwiftUI

struct TaskBoardPanel: View {
    let session: WorkspaceSession

    @State private var newTaskTitle = ""

    private var store: TaskBoardStore { session.taskBoard }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapMedium) {
                    header
                    if let board = store.board {
                        ForEach(TaskState.allCases, id: \.self) { state in
                            stateGroup(state, tasks: board.tasks(in: state))
                        }
                    } else if !store.fileExists {
                        emptyState
                    }
                }
                .padding(DevtailTokens.Spacing.cardPadding)
            }
            if store.board != nil {
                addField
            }
        }
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

    private func stateGroup(_ state: TaskState, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
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
            if tasks.isEmpty {
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
            } else {
                ForEach(tasks) { task in
                    taskCard(task)
                }
            }
        }
    }

    private func taskCard(_ task: TaskItem) -> some View {
        HStack(alignment: .center, spacing: DevtailTokens.Spacing.gapSmall) {
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

            Text(task.title)
                .font(DevtailTokens.Typography.caption)
                .foregroundStyle(task.state == .done
                    ? DevtailTokens.Colors.textTertiary
                    : DevtailTokens.Colors.textSecondary)
                .strikethrough(task.state == .done)
                .lineLimit(2)
                .help(task.title)

            Spacer(minLength: 0)

            Menu {
                ForEach(TaskState.allCases.filter { $0 != task.state }, id: \.self) { target in
                    Button("Move to \(target.displayName)") {
                        store.moveTask(id: task.id, to: target)
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
    }

    /// One state-color mapping shared by the section dots and the card
    /// spines — Doing carries the app accent (it is "what is active now"),
    /// Pending/Done reuse the traffic palette.
    private static func stateColor(_ state: TaskState) -> Color {
        switch state {
        case .doing: DevtailTokens.Colors.accentPrimary
        case .pending: DevtailTokens.Colors.trafficYellow
        case .done: DevtailTokens.Colors.trafficGreen
        }
    }

    private var addField: some View {
        HStack(spacing: DevtailTokens.Spacing.gapSmall) {
            TextField("Add a task", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(DevtailTokens.Typography.caption)
                .onSubmit(submitNewTask)
            Button(action: submitNewTask) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.icon)
            .foregroundStyle(.secondary)
            .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .help("Add to Pending")
        }
        .padding(DevtailTokens.Spacing.cardPadding)
        .background(DevtailTokens.Colors.titleBar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DevtailTokens.Colors.borderSubtle)
                .frame(height: DevtailTokens.BorderWidth.default)
        }
    }

    private func submitNewTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        store.addTask(title: title)
        newTaskTitle = ""
    }
}
