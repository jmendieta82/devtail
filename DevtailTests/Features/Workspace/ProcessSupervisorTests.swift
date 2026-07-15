import Foundation
import Testing
@testable import Devtail

@MainActor
struct ProcessSupervisorTests {
    private func makeSUT() -> (ProcessSupervisor, MockTerminalEngine, MockBrowserLauncher) {
        let engine = MockTerminalEngine()
        let browser = MockBrowserLauncher()
        return (ProcessSupervisor(engine: engine, browserLauncher: browser), engine, browser)
    }

    private func pane(_ label: String, cwd: String = ".", command: String = "npm run dev",
                      order: Int, slot: Int = -1, frontend: Bool = false, url: String? = nil) -> WorkspacePane {
        WorkspacePane(label: label, relativeCwd: cwd, command: command, order: order,
                      layoutSlot: slot, isFrontend: frontend, localhostUrl: url, project: nil)
    }

    @Test func configureMapsPanesSortedByOrderIgnoringLayoutSlot() {
        let (sut, _, _) = makeSUT()
        let root = URL(fileURLWithPath: "/tmp/proj", isDirectory: true)
        // Legacy project shape: layoutSlot values present — must be irrelevant.
        sut.configure(panes: [pane("front", cwd: "web", order: 1, slot: 3),
                              pane("back", cwd: "api", order: 0, slot: 0)], root: root)
        #expect(sut.processes.map(\.name) == ["back", "front"])
        #expect(sut.processes[0].cwd.path == "/tmp/proj/api")
        #expect(sut.processes.allSatisfy { $0.state == .stopped })
    }

    @Test func startSpawnsReadOnlySessionAndRuns() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", cwd: "api", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        #expect(sut.processes[0].state == .running)
        #expect(engine.sessions.count == 1)
        #expect(engine.sessions[0].startCount == 1)
        #expect(engine.configs[0].readOnly)
        #expect(engine.configs[0].command == "npm run dev")
    }

    @Test func startAllStartsEveryProcessAndOpensFrontendBrowserOnce() {
        let (sut, engine, browser) = makeSUT()
        sut.configure(panes: [pane("back", order: 0),
                              pane("front", order: 1, frontend: true, url: "http://localhost:4200")],
                      root: URL(fileURLWithPath: "/tmp/p"))
        sut.startAll()
        #expect(engine.sessions.count == 2)
        #expect(browser.urlStrings == ["http://localhost:4200"])
    }

    @Test func exitCallbackMovesStateToExitedWithCode() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        engine.sessions[0].simulateExit(code: 137)
        #expect(sut.processes[0].state == .exited(137))
    }

    @Test func stopTerminatesSessionAndMarksStopped() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        sut.stop(sut.processes[0])
        #expect(engine.sessions[0].terminateCount == 1)
        #expect(sut.processes[0].state == .stopped)
    }

    @Test func restartCreatesFreshSessionSoLogIsClean() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        sut.restart(sut.processes[0])
        // Old session terminated, NEW session spawned — fresh scrollback by construction.
        #expect(engine.sessions.count == 2)
        #expect(engine.sessions[0].terminateCount == 1)
        #expect(engine.sessions[1].startCount == 1)
        #expect(sut.processes[0].session === engine.sessions[1])
        #expect(sut.processes[0].state == .running)
    }

    @Test func shutdownAllTerminatesEveryRunningSession() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("a", order: 0), pane("b", order: 1)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.startAll()
        sut.shutdownAll()
        #expect(engine.sessions.allSatisfy { $0.terminateCount == 1 })
        #expect(sut.processes.allSatisfy { $0.state == .stopped })
    }

    @Test func exitAfterStopDoesNotResurrectExitedState() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        sut.stop(sut.processes[0])
        // killpg → child dies → PTY reports exit AFTER we already marked stopped.
        engine.sessions[0].simulateExit(code: 0)
        #expect(sut.processes[0].state == .stopped)
    }

    @Test func staleExitFromReplacedSessionDoesNotKillRestartedProcess() {
        let (sut, engine, _) = makeSUT()
        sut.configure(panes: [pane("back", order: 0)], root: URL(fileURLWithPath: "/tmp/p"))
        sut.start(sut.processes[0])
        sut.restart(sut.processes[0])
        // The OLD session's child dies late — its exit must not touch the
        // process now owned by the NEW session.
        engine.sessions[0].simulateExit(code: 137)
        #expect(sut.processes[0].state == .running)
    }
}
