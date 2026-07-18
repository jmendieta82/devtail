//
//  TaskBoardPanel.swift
//  Devtail
//
//  Side-panel task board over .devtail/tasks.md: three state groups,
//  checkbox toggling (Done vs Pending), a move menu per task, archive
//  for the Done group, and quick-add into Pending. Refreshes on appear
//  so agent-written items show up when the panel opens.
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
            HStack {
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
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            } else {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DevtailTokens.Spacing.gapSmall) {
            Button {
                store.moveTask(id: task.id, to: task.state == .done ? .pending : .done)
            } label: {
                Image(systemName: task.state == .done ? "checkmark.square" : "square")
                    .font(.system(size: 12))
                    .foregroundStyle(task.state == .done
                        ? DevtailTokens.Colors.trafficGreen
                        : DevtailTokens.Colors.textSecondary)
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
