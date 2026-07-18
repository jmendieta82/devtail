//
//  TaskBoardStore.swift
//  Devtail
//
//  Observable task-board state for the workspace side panel. Composed
//  into WorkspaceSession like FileTreeStore/FileSearchStore. The file is
//  the source of truth: every mutation renders and writes the whole
//  board, and a failed write re-refreshes from disk so the UI never
//  shows state the file does not have. Explicit refresh only (no file
//  watcher) — same model as the git/Claude cards.
//

import Foundation

@Observable
final class TaskBoardStore {

    let boardURL: URL
    let archiveURL: URL
    private let fileAccess: TaskBoardFileAccessing

    /// Nil until the first successful load, and nil when the file does
    /// not exist — pair with `fileExists` to tell those apart.
    private(set) var board: TaskBoard?
    private(set) var fileExists = false

    /// In-flight I/O task (refresh or mutation), exposed read-only so
    /// tests await completion instead of sleeping. Serialized: every
    /// operation cancels-or-chains behind the previous one by replacing
    /// this handle after awaiting its own work.
    @ObservationIgnored private(set) var ioTask: Task<Void, Never>?

    init(root: URL, fileAccess: TaskBoardFileAccessing = TaskBoardFileAccess()) {
        let devtailDir = root.appendingPathComponent(".devtail", isDirectory: true)
        self.boardURL = devtailDir.appendingPathComponent("tasks.md")
        self.archiveURL = devtailDir.appendingPathComponent("tasks-archive.md")
        self.fileAccess = fileAccess
    }

    /// Reload from disk. Cancels any in-flight operation; assigns only
    /// when not cancelled (no-assign-when-cancelled, like refreshGitStatus).
    func refresh() {
        ioTask?.cancel()
        ioTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let text = await self.fileAccess.read(at: self.boardURL)
            guard !Task.isCancelled else { return }
            self.fileExists = text != nil
            self.board = text.map(TaskBoardParser.parse)
        }
    }

    /// Writes the empty template (first-use path), then loads it.
    func createBoard() {
        ioTask?.cancel()
        ioTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let template = TaskBoardParser.render(.empty)
            guard await self.fileAccess.write(template, to: self.boardURL) else { return }
            guard !Task.isCancelled else { return }
            self.fileExists = true
            self.board = TaskBoardParser.parse(template)
        }
    }

    func addTask(title: String) {
        mutate { $0.add(title: title) }
    }

    func moveTask(id: UUID, to target: TaskState) {
        mutate { $0.move(id: id, to: target) }
    }

    /// Archives Done tasks: append to the archive file under a dated
    /// heading FIRST, and only rewrite the board when that append
    /// succeeded — a failed archive re-refreshes from disk, restoring the
    /// Done tasks (they were never removed from the file). Optimistic like
    /// `mutate` — the in-memory board drops the Done tasks immediately, so
    /// a mutation issued while the archive I/O is in flight derives from
    /// the post-archive board instead of resurrecting the archived tasks
    /// through its own chained write.
    func archiveDone(on date: Date) {
        guard var working = board, !working.tasks(in: .done).isEmpty else { return }
        let removed = working.removeDoneTasks()
        board = working
        let heading = Self.archiveDateFormatter.string(from: date)
        let block = "## \(heading)\n" + removed.map { "- [x] \($0.title)" }.joined(separator: "\n") + "\n\n"
        let previous = ioTask
        ioTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            guard await self.fileAccess.append(block, to: self.archiveURL) else {
                await self.refreshFromDisk()
                return
            }
            if await !self.fileAccess.write(TaskBoardParser.render(working), to: self.boardURL) {
                await self.refreshFromDisk()
            }
        }
    }

    /// Cancels any in-flight I/O — called from session teardown.
    func cancel() {
        ioTask?.cancel()
        ioTask = nil
    }

    /// Shared mutation path, optimistic + serialized: the board is
    /// updated in place immediately (so rapid successive mutations
    /// compose instead of deriving from a stale copy), and the rendered
    /// snapshot is written behind any in-flight write (FIFO — the last
    /// snapshot contains all prior changes, so last-write-wins is
    /// correct). A failed write re-refreshes from disk so the UI never
    /// drifts from the file for long.
    private func mutate(_ change: (inout TaskBoard) -> Void) {
        guard var working = board else { return }
        change(&working)
        board = working
        let snapshot = working
        let previous = ioTask
        ioTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            if await !self.fileAccess.write(TaskBoardParser.render(snapshot), to: self.boardURL) {
                await self.refreshFromDisk()
            }
        }
    }

    @MainActor
    private func refreshFromDisk() async {
        let text = await fileAccess.read(at: boardURL)
        fileExists = text != nil
        board = text.map(TaskBoardParser.parse)
    }

    /// Archive headings are calendar dates in UTC — stable regardless of
    /// the machine's locale.
    private static let archiveDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
