//
//  TaskBoard.swift
//  Devtail
//
//  In-memory model of a project's .devtail/tasks.md. The SECTION a task
//  sits in is the source of truth for its state — checkboxes are
//  normalized on render. Non-task lines are kept as .raw entries so a
//  rewrite never destroys agent- or hand-written notes.
//

import Foundation

/// The three board states, each backed by a markdown section heading.
enum TaskState: String, CaseIterable, Sendable {
    case doing
    case pending
    case done

    var heading: String {
        switch self {
        case .doing: "## Doing"
        case .pending: "## Pending"
        case .done: "## Done"
        }
    }

    var displayName: String {
        switch self {
        case .doing: "Doing"
        case .pending: "Pending"
        case .done: "Done"
        }
    }
}

/// One task on the board. `id` is assigned at parse time and stable for
/// the lifetime of the loaded board (not persisted to the file).
struct TaskItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var state: TaskState

    init(id: UUID = UUID(), title: String, state: TaskState) {
        self.id = id
        self.title = title
        self.state = state
    }
}

/// A line inside a section: either a parsed task or an unknown line kept
/// verbatim for round-trip preservation.
enum TaskBoardLine: Equatable, Sendable {
    case task(TaskItem)
    case raw(String)
}

struct TaskBoard: Equatable, Sendable {
    /// Lines before the first known section heading, preserved verbatim.
    var preamble: [String]
    var sections: [TaskState: [TaskBoardLine]]

    /// The documented on-disk template shape.
    static var empty: TaskBoard {
        TaskBoard(preamble: ["# Tasks", ""], sections: [:])
    }

    func tasks(in state: TaskState) -> [TaskItem] {
        (sections[state] ?? []).compactMap {
            if case .task(let item) = $0 { return item }
            return nil
        }
    }

    /// New tasks always enter Pending, at the end.
    mutating func add(title: String) {
        sections[.pending, default: []].append(
            .task(TaskItem(title: title, state: .pending))
        )
    }

    /// Moves a task to the end of the target section, updating its state.
    /// No-op when the id is not on the board or already in the target.
    mutating func move(id: UUID, to target: TaskState) {
        for state in TaskState.allCases {
            guard var lines = sections[state],
                  let index = lines.firstIndex(where: {
                      if case .task(let item) = $0 { return item.id == id }
                      return false
                  }),
                  case .task(var item) = lines[index] else { continue }
            guard state != target else { return }
            lines.remove(at: index)
            sections[state] = lines
            item.state = target
            sections[target, default: []].append(.task(item))
            return
        }
    }

    /// Removes and returns every task in Done (raw lines stay), for the
    /// archive flow.
    mutating func removeDoneTasks() -> [TaskItem] {
        var removed: [TaskItem] = []
        sections[.done] = (sections[.done] ?? []).filter { line in
            if case .task(let item) = line {
                removed.append(item)
                return false
            }
            return true
        }
        return removed
    }
}
