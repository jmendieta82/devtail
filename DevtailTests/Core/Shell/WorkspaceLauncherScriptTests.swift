//
//  WorkspaceLauncherScriptTests.swift
//  DevtailTests
//
//  Golden-string tests for the buildLaunchScript(_:_:) pure function.
//  Verifies the native Ghostty AppleScript dictionary output — no System
//  Events keystroke simulation.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("WorkspaceLauncher — buildLaunchScript (native Ghostty AppleScript)")
struct WorkspaceLauncherScriptTests {

    // Helper: a Project instance is required because WorkspacePane has a
    // @Relationship back to Project. We use a non-persisted Project — the
    // function only reads label/cwd/command/order/splitDirection.
    private func makeProject() -> Project {
        Project(name: "Test", color: .green, environment: .dev)
    }

    private func pane(
        _ cwd: String,
        _ cmd: String,
        order: Int = 0,
        split: String = "none",
        label: String = "Main"
    ) -> WorkspacePane {
        WorkspacePane(
            label: label,
            relativeCwd: cwd,
            command: cmd,
            order: order,
            splitDirection: split,
            project: makeProject()
        )
    }

    // MARK: - Empty & single-pane cases

    @Test("0 panes → only activate Ghostty, no window creation")
    func zeroPanes() {
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: [])
        #expect(script.contains("tell application \"Ghostty\""))
        #expect(script.contains("activate"))
        #expect(script.contains("end tell"))
        #expect(!script.contains("new window"))
        #expect(!script.contains("new surface configuration"))
        #expect(!script.contains("split"))
    }

    @Test("1 pane, empty command, cwd=. → new window at root, no input text")
    func onePaneEmpty() {
        let panes = [pane(".", "")]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)
        #expect(script.contains("new surface configuration"))
        #expect(script.contains("set initial working directory of mainCfg to \"/tmp/proj\""))
        #expect(script.contains("new window with configuration mainCfg"))
        #expect(script.contains("set term0 to focused terminal of selected tab of win"))
        #expect(!script.contains("input text"))
        #expect(!script.contains("send key"))
    }

    @Test("1 pane, command=claude, cwd=. → window + input text + enter")
    func onePaneClaude() {
        let panes = [pane(".", "claude")]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)
        #expect(script.contains("set initial working directory of mainCfg to \"/tmp/proj\""))
        #expect(script.contains("input text \"claude\" to term0"))
        #expect(script.contains("send key \"enter\" to term0"))
    }

    @Test("1 pane, cwd=./frontend → resolved absolute path in initial working directory")
    func onePaneWithCwd() {
        let panes = [pane("./frontend", "ng serve")]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)
        #expect(script.contains("set initial working directory of mainCfg to \"/tmp/proj/frontend\""))
        #expect(script.contains("input text \"ng serve\" to term0"))
    }

    @Test("1 pane, cwd=./sub, empty command → window created with resolved path, no input")
    func onePaneCdOnly() {
        let panes = [pane("./sub", "")]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)
        #expect(script.contains("set initial working directory of mainCfg to \"/tmp/proj/sub\""))
        #expect(!script.contains("input text"))
    }

    // MARK: - Multi-pane splits

    @Test("2 panes (right split) → window + split right + both configs + focus term0")
    func twoPanesRight() {
        let panes = [
            pane(".", "claude", order: 0),
            pane("./frontend", "ng serve", order: 1, split: "right")
        ]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)

        // Main window
        #expect(script.contains("set initial working directory of mainCfg to \"/tmp/proj\""))
        #expect(script.contains("input text \"claude\" to term0"))

        // Split right from term0 → term1 with frontend config
        #expect(script.contains("set cfg1 to new surface configuration"))
        #expect(script.contains("set initial working directory of cfg1 to \"/tmp/proj/frontend\""))
        #expect(script.contains("set term1 to split term0 direction right with configuration cfg1"))

        // Defensive cd fallback + command
        #expect(script.contains("input text \"cd /tmp/proj/frontend\" to term1"))
        #expect(script.contains("input text \"ng serve\" to term1"))

        // Focus back on main
        #expect(script.contains("focus term0"))
    }

    @Test("3 panes (right + down) → 2 splits with correct chain + all commands")
    func threePanesRightDown() {
        let panes = [
            pane(".", "claude", order: 0),
            pane("./frontend", "ng serve", order: 1, split: "right"),
            pane("./backend", "npm run start:dev", order: 2, split: "down")
        ]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)

        // Main window at root
        #expect(script.contains("set initial working directory of mainCfg to \"/tmp/proj\""))
        #expect(script.contains("input text \"claude\" to term0"))

        // Pane 1: split right from term0
        #expect(script.contains("set initial working directory of cfg1 to \"/tmp/proj/frontend\""))
        #expect(script.contains("set term1 to split term0 direction right with configuration cfg1"))
        #expect(script.contains("input text \"cd /tmp/proj/frontend\" to term1"))
        #expect(script.contains("input text \"ng serve\" to term1"))

        // Pane 2: split DOWN from term1 (not term0 — chain from previous)
        #expect(script.contains("set initial working directory of cfg2 to \"/tmp/proj/backend\""))
        #expect(script.contains("set term2 to split term1 direction down with configuration cfg2"))
        #expect(script.contains("input text \"cd /tmp/proj/backend\" to term2"))
        #expect(script.contains("input text \"npm run start:dev\" to term2"))

        // Final focus back on main
        #expect(script.contains("focus term0"))
    }

    // MARK: - Content handling

    @Test("Command with shell meta chars passes through verbatim")
    func specialChars() {
        let panes = [pane(".", "claude --resume && echo done")]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)
        #expect(script.contains("input text \"claude --resume && echo done\" to term0"))
    }

    @Test("Whitespace is trimmed from command")
    func trimsWhitespace() {
        let panes = [pane("./api", "  npm start  ")]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)
        #expect(script.contains("input text \"npm start\" to term0"))
    }

    @Test("Command with double quote is escaped")
    func escapesDoubleQuote() {
        let panes = [pane(".", #"echo "hello""#)]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)
        // The literal "hello" inside the command should be escaped as \"hello\"
        #expect(script.contains(#"input text "echo \"hello\"" to term0"#))
    }

    // MARK: - Split direction handling

    @Test("Split=none on non-first pane → skipped, no split emitted")
    func noneSplitSkipped() {
        let panes = [
            pane(".", "claude", order: 0),
            pane("./api", "npm start", order: 1, split: "none")
        ]
        let script = buildLaunchScript(directoryPath: "/tmp/proj", panes: panes)
        // Pane 1 is skipped because split direction is "none"
        #expect(!script.contains("split term0 direction"))
        #expect(!script.contains("term1"))
        // No focus term0 needed since there's effectively 1 pane
        #expect(!script.contains("focus term0"))
    }

    // MARK: - Path resolution

    @Test("resolvedPath with '.' returns root unchanged")
    func resolvedPathRoot() {
        #expect(resolvedPath(rootPath: "/tmp/proj", relativeCwd: ".") == "/tmp/proj")
    }

    @Test("resolvedPath strips leading ./ from relative")
    func resolvedPathStripsDotSlash() {
        #expect(resolvedPath(rootPath: "/tmp/proj", relativeCwd: "./frontend") == "/tmp/proj/frontend")
    }

    @Test("resolvedPath handles nested relative")
    func resolvedPathNested() {
        #expect(resolvedPath(rootPath: "/tmp/proj", relativeCwd: "./apps/web") == "/tmp/proj/apps/web")
    }

    @Test("resolvedPath handles empty relative as root")
    func resolvedPathEmpty() {
        #expect(resolvedPath(rootPath: "/tmp/proj", relativeCwd: "") == "/tmp/proj")
    }

    @Test("resolvedPath handles trailing slash on root")
    func resolvedPathTrailingSlash() {
        #expect(resolvedPath(rootPath: "/tmp/proj/", relativeCwd: "./sub") == "/tmp/proj/sub")
    }
}
