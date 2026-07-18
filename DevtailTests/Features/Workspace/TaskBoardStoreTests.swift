//
//  TaskBoardStoreTests.swift
//  DevtailTests
//
//  TaskBoardStore wiring against the in-memory file double: refresh
//  assign/no-assign semantics, create, write-through mutations, the
//  write-failure re-refresh contract, and archive append-before-remove.
//

import Testing
import Foundation
@testable import Devtail

@Suite("TaskBoardStore")
@MainActor
struct TaskBoardStoreTests {

    private static let root = URL(fileURLWithPath: "/fake/project")

    private func makeStore(files: [String: String] = [:]) -> (TaskBoardStore, MockTaskBoardFileAccess) {
        let mock = MockTaskBoardFileAccess()
        let store = TaskBoardStore(root: Self.root, fileAccess: mock)
        for (relative, content) in files {
            mock.files[Self.root.appendingPathComponent(relative)] = content
        }
        return (store, mock)
    }

    @Test("refresh loads and parses the board file")
    func refreshLoads() async {
        let (store, _) = makeStore(files: [".devtail/tasks.md": "## Pending\n- [ ] a\n"])
        store.refresh()
        await store.ioTask?.value
        #expect(store.fileExists == true)
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["a"])
    }

    @Test("refresh with a missing file reports fileExists false and no board")
    func refreshMissingFile() async {
        let (store, _) = makeStore()
        store.refresh()
        await store.ioTask?.value
        #expect(store.fileExists == false)
        #expect(store.board == nil)
    }

    @Test("cancelled refresh does not assign")
    func cancelledRefreshDoesNotAssign() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": "## Pending\n- [ ] a\n"])
        mock.readDelayNanoseconds = 50_000_000
        store.refresh()
        // Capture before cancel(): cancel() nils the handle, and the test
        // must await the cancelled task to deterministically observe that
        // it finished WITHOUT assigning.
        let inFlight = store.ioTask
        store.cancel()
        await inFlight?.value
        #expect(store.board == nil)
    }

    @Test("two rapid mutations both survive (writes are serialized)")
    func rapidMutationsCompose() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": TaskBoardParser.render(.empty)])
        store.refresh()
        await store.ioTask?.value
        store.addTask(title: "first")
        store.addTask(title: "second")
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["first", "second"])
        let written = mock.files[store.boardURL] ?? ""
        #expect(written.contains("- [ ] first"))
        #expect(written.contains("- [ ] second"))
    }

    @Test("createBoard writes the template and loads it")
    func createBoardWritesTemplate() async {
        let (store, mock) = makeStore()
        store.createBoard()
        await store.ioTask?.value
        #expect(mock.files[store.boardURL] == TaskBoardParser.render(.empty))
        #expect(store.board != nil)
        #expect(store.fileExists == true)
    }

    @Test("addTask writes the updated board through to the file")
    func addTaskWritesThrough() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": TaskBoardParser.render(.empty)])
        store.refresh()
        await store.ioTask?.value
        store.addTask(title: "from ui")
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["from ui"])
        #expect(mock.files[store.boardURL]?.contains("- [ ] from ui") == true)
    }

    @Test("addTask to an explicit state persists in that section")
    func addTaskToDoingPersists() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": TaskBoardParser.render(.empty)])
        store.refresh()
        await store.ioTask?.value
        store.addTask(title: "now", to: .doing)
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .doing).map(\.title) == ["now"])
        let written = mock.files[store.boardURL] ?? ""
        #expect(written.contains("## Doing"))
        #expect(written.contains("- [ ] now"))
    }

    @Test("renameTask updates the title and persists")
    func renameTaskPersists() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": "## Pending\n- [ ] typo\n"])
        store.refresh()
        await store.ioTask?.value
        let id = store.board!.tasks(in: .pending)[0].id
        store.renameTask(id: id, to: "fixed")
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["fixed"])
        #expect(mock.files[store.boardURL]?.contains("- [ ] fixed") == true)
        #expect(mock.files[store.boardURL]?.contains("typo") == false)
    }

    @Test("moveTask relocates and persists")
    func moveTaskPersists() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": "## Pending\n- [ ] a\n"])
        store.refresh()
        await store.ioTask?.value
        let id = store.board!.tasks(in: .pending)[0].id
        store.moveTask(id: id, to: .doing)
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .doing).map(\.title) == ["a"])
        let written = mock.files[store.boardURL] ?? ""
        #expect(written.range(of: "## Doing\n- [ ] a") != nil)
    }

    @Test("failed write re-refreshes from disk so UI never drifts from the file")
    func failedWriteReRefreshes() async {
        let original = "## Pending\n- [ ] a\n"
        let (store, mock) = makeStore(files: [".devtail/tasks.md": original])
        store.refresh()
        await store.ioTask?.value
        mock.failWrites = true
        store.addTask(title: "will not stick")
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["a"])
        #expect(mock.files[store.boardURL] == original)
    }

    @Test("archiveDone appends to the archive with a date heading and clears Done")
    func archiveDoneAppendsAndClears() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": "## Done\n- [x] shipped\n"])
        store.refresh()
        await store.ioTask?.value
        store.archiveDone(on: Date(timeIntervalSince1970: 1_784_332_800))
        await store.ioTask?.value
        let archive = mock.files[store.archiveURL] ?? ""
        #expect(archive.contains("## 2026-07-18"))
        #expect(archive.contains("- [x] shipped"))
        #expect(store.board?.tasks(in: .done).isEmpty == true)
        #expect(mock.files[store.boardURL]?.contains("shipped") == false)
    }

    @Test("archiveDone with a failed append leaves the board and file untouched")
    func archiveAppendFailureLeavesBoard() async {
        let original = "## Done\n- [x] shipped\n"
        let (store, mock) = makeStore(files: [".devtail/tasks.md": original])
        store.refresh()
        await store.ioTask?.value
        mock.failAppends = true
        store.archiveDone(on: Date(timeIntervalSince1970: 1_784_332_800))
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .done).map(\.title) == ["shipped"])
        #expect(mock.files[store.boardURL] == original)
    }

    @Test("archiveDone with an empty Done section is a no-op")
    func archiveEmptyDoneNoop() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": TaskBoardParser.render(.empty)])
        store.refresh()
        await store.ioTask?.value
        store.archiveDone(on: Date(timeIntervalSince1970: 1_784_332_800))
        await store.ioTask?.value
        #expect(mock.files[store.archiveURL] == nil)
    }

    @Test("addTask during an in-flight archive does not resurrect archived tasks")
    func addDuringArchiveDoesNotResurrect() async {
        let (store, mock) = makeStore(files: [".devtail/tasks.md": "## Done\n- [x] shipped\n"])
        store.refresh()
        await store.ioTask?.value
        // Hold the archive's append in flight so the add interleaves
        // behind it — the exact window where a non-optimistic archive let
        // the chained mutation write the pre-archive board back to disk.
        mock.appendDelayNanoseconds = 50_000_000
        store.archiveDone(on: Date(timeIntervalSince1970: 1_784_332_800))
        store.addTask(title: "quick add")
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .done).isEmpty == true)
        #expect(store.board?.tasks(in: .pending).map(\.title) == ["quick add"])
        let written = mock.files[store.boardURL] ?? ""
        #expect(written.contains("shipped") == false)
        #expect(written.contains("- [ ] quick add"))
        #expect((mock.files[store.archiveURL] ?? "").contains("- [x] shipped"))
    }

    @Test("addTask chained behind a FAILED archive append never loses the Done tasks")
    func addDuringFailedArchiveKeepsDoneTasks() async {
        let original = "## Done\n- [x] shipped\n"
        let (store, mock) = makeStore(files: [".devtail/tasks.md": original])
        store.refresh()
        await store.ioTask?.value
        // Failed archive restores the board from disk; the chained add's
        // write must render the RESTORED board, not its queue-time
        // snapshot — a stale snapshot would persist the post-archive
        // state, losing "shipped" from both files. The interleaved add
        // itself is knowingly discarded by the restore (rare failure
        // path, user sees the board revert).
        mock.appendDelayNanoseconds = 50_000_000
        mock.failAppends = true
        store.archiveDone(on: Date(timeIntervalSince1970: 1_784_332_800))
        store.addTask(title: "quick add")
        await store.ioTask?.value
        #expect(store.board?.tasks(in: .done).map(\.title) == ["shipped"])
        #expect(mock.files[store.archiveURL] == nil)
        let written = mock.files[store.boardURL] ?? original
        #expect(written.contains("- [x] shipped"))
    }
}
