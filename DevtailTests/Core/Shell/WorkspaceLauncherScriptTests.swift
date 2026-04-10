//
//  WorkspaceLauncherScriptTests.swift
//  DevtailTests
//
//  Golden-string tests for the buildLaunchScript(directoryPath:layout:panesBySlot:)
//  pure function. Verifies the native Ghostty AppleScript dictionary output for
//  all 4 layouts and validates the pre-flight slot-coverage check.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("WorkspaceLauncher — buildLaunchScript (layout-driven)")
struct WorkspaceLauncherScriptTests {

    private func makeProject() -> Project {
        Project(name: "Test", color: .green)
    }

    private func pane(
        _ cwd: String,
        _ cmd: String,
        slot: Int,
        label: String = "Main"
    ) -> WorkspacePane {
        WorkspacePane(
            label: label,
            relativeCwd: cwd,
            command: cmd,
            order: slot,
            layoutSlot: slot,
            project: makeProject()
        )
    }

    // MARK: - Full layout

    @Test("Full layout — one window, zero splits")
    func fullLayout() throws {
        let p = pane(".", "claude", slot: 0)
        let script = try buildLaunchScript(
            directoryPath: "/tmp/proj",
            layout: .full,
            panesBySlot: [0: p]
        )
        #expect(script.contains("tell application \"Ghostty\""))
        #expect(script.contains("activate"))
        #expect(script.contains("new window with configuration cfg0"))
        #expect(script.contains("set term0 to focused terminal of selected tab of win"))
        #expect(script.contains("input text \"claude\" to term0"))
        #expect(!script.contains("split"))
        #expect(!script.contains("focus term0"))
    }

    @Test("Full layout — no command produces no input text")
    func fullLayoutNoCommand() throws {
        let p = pane(".", "", slot: 0)
        let script = try buildLaunchScript(
            directoryPath: "/tmp/proj",
            layout: .full,
            panesBySlot: [0: p]
        )
        #expect(!script.contains("input text"))
        #expect(!script.contains("send key"))
    }

    // MARK: - HalvesVertical layout

    @Test("HalvesVertical — split term0 direction right to produce term1")
    func halvesVerticalLayout() throws {
        let slot0 = pane(".", "claude", slot: 0)
        let slot1 = pane("./frontend", "ng serve", slot: 1)
        let script = try buildLaunchScript(
            directoryPath: "/tmp/proj",
            layout: .halvesVertical,
            panesBySlot: [0: slot0, 1: slot1]
        )
        #expect(script.contains("set initial working directory of cfg0 to \"/tmp/proj\""))
        #expect(script.contains("set cfg1 to new surface configuration"))
        #expect(script.contains("set initial working directory of cfg1 to \"/tmp/proj/frontend\""))
        #expect(script.contains("set term1 to split term0 direction right with configuration cfg1"))
        #expect(script.contains("input text \"cd /tmp/proj/frontend\" to term1"))
        #expect(script.contains("input text \"ng serve\" to term1"))
        #expect(script.contains("focus term0"))
        #expect(!script.contains("split term1"))
    }

    // MARK: - MainSideStack layout

    @Test("MainSideStack — two sequential splits: term0→right→term1, term1→down→term2")
    func mainSideStackLayout() throws {
        let slot0 = pane(".", "claude", slot: 0)
        let slot1 = pane("./api", "npm run dev", slot: 1)
        let slot2 = pane("./front", "ng serve", slot: 2)
        let script = try buildLaunchScript(
            directoryPath: "/tmp/proj",
            layout: .mainSideStack,
            panesBySlot: [0: slot0, 1: slot1, 2: slot2]
        )
        #expect(script.contains("set term1 to split term0 direction right with configuration cfg1"))
        #expect(script.contains("set term2 to split term1 direction down with configuration cfg2"))
        #expect(script.contains("input text \"cd /tmp/proj/api\" to term1"))
        #expect(script.contains("input text \"npm run dev\" to term1"))
        #expect(script.contains("input text \"cd /tmp/proj/front\" to term2"))
        #expect(script.contains("input text \"ng serve\" to term2"))
        #expect(script.contains("focus term0"))
    }

    // MARK: - Quarters layout (non-sequential sources — the critical test)

    @Test("Quarters — non-sequential splits: term0→right→term1, term0→down→term2, term1→down→term3")
    func quartersLayout() throws {
        let slot0 = pane(".", "", slot: 0)
        let slot1 = pane("./api", "npm start", slot: 1)
        let slot2 = pane("./front", "ng serve", slot: 2)
        let slot3 = pane("./logs", "tail -f app.log", slot: 3)
        let script = try buildLaunchScript(
            directoryPath: "/tmp/proj",
            layout: .quarters,
            panesBySlot: [0: slot0, 1: slot1, 2: slot2, 3: slot3]
        )

        // Step 1: term0 → right → term1
        #expect(script.contains("set term1 to split term0 direction right with configuration cfg1"))

        // Step 2: term0 → down → term2 (NOT term1 — non-sequential)
        #expect(script.contains("set term2 to split term0 direction down with configuration cfg2"))

        // Step 3: term1 → down → term3 (NOT term2)
        #expect(script.contains("set term3 to split term1 direction down with configuration cfg3"))

        // Content phase
        #expect(script.contains("input text \"cd /tmp/proj/api\" to term1"))
        #expect(script.contains("input text \"npm start\" to term1"))
        #expect(script.contains("input text \"cd /tmp/proj/front\" to term2"))
        #expect(script.contains("input text \"ng serve\" to term2"))
        #expect(script.contains("input text \"cd /tmp/proj/logs\" to term3"))
        #expect(script.contains("focus term0"))
    }

    @Test("Quarters — term2 splits from term0, not term1 (source order assertion)")
    func quartersSourceOrder() throws {
        let slots: [Int: WorkspacePane] = [
            0: pane(".", "", slot: 0),
            1: pane("./a", "", slot: 1),
            2: pane("./b", "", slot: 2),
            3: pane("./c", "", slot: 3)
        ]
        let script = try buildLaunchScript(
            directoryPath: "/p",
            layout: .quarters,
            panesBySlot: slots
        )
        // term2 MUST reference term0 as source — not term1
        let lines = script.components(separatedBy: "\n")
        let term2Line = lines.first { $0.contains("set term2 to split") }
        #expect(term2Line?.contains("split term0 direction down") == true)

        // term3 MUST reference term1 as source — not term2
        let term3Line = lines.first { $0.contains("set term3 to split") }
        #expect(term3Line?.contains("split term1 direction down") == true)
    }

    // MARK: - Pre-validation: layoutHasUnassignedSlots

    @Test("Missing slot 1 in halvesVertical throws layoutHasUnassignedSlots([1])")
    func missingSlotHalves() {
        let slot0 = pane(".", "", slot: 0)
        #expect(throws: WorkspaceLauncherError.layoutHasUnassignedSlots(missing: [1])) {
            try buildLaunchScript(
                directoryPath: "/tmp/proj",
                layout: .halvesVertical,
                panesBySlot: [0: slot0]
            )
        }
    }

    @Test("Quarters with only slot 0 throws layoutHasUnassignedSlots([1, 2, 3])")
    func missingSlots123() {
        let slot0 = pane(".", "", slot: 0)
        #expect(throws: WorkspaceLauncherError.layoutHasUnassignedSlots(missing: [1, 2, 3])) {
            try buildLaunchScript(
                directoryPath: "/tmp/proj",
                layout: .quarters,
                panesBySlot: [0: slot0]
            )
        }
    }

    @Test("Quarters with slot 2 missing throws layoutHasUnassignedSlots([2])")
    func missingSlot2() {
        let slot0 = pane(".", "", slot: 0)
        let slot1 = pane("./a", "", slot: 1)
        let slot3 = pane("./c", "", slot: 3)
        #expect(throws: WorkspaceLauncherError.layoutHasUnassignedSlots(missing: [2])) {
            try buildLaunchScript(
                directoryPath: "/tmp/proj",
                layout: .quarters,
                panesBySlot: [0: slot0, 1: slot1, 3: slot3]
            )
        }
    }

    // MARK: - Content escaping

    @Test("Command with shell meta chars passes through verbatim")
    func specialChars() throws {
        let p = pane(".", "claude --resume && echo done", slot: 0)
        let script = try buildLaunchScript(
            directoryPath: "/tmp/proj",
            layout: .full,
            panesBySlot: [0: p]
        )
        #expect(script.contains("input text \"claude --resume && echo done\" to term0"))
    }

    @Test("Command with double quote is escaped")
    func escapesDoubleQuote() throws {
        let p = pane(".", #"echo "hello""#, slot: 0)
        let script = try buildLaunchScript(
            directoryPath: "/tmp/proj",
            layout: .full,
            panesBySlot: [0: p]
        )
        #expect(script.contains(#"input text "echo \"hello\"" to term0"#))
    }

    @Test("Whitespace is trimmed from command")
    func trimsWhitespace() throws {
        let p = pane("./api", "  npm start  ", slot: 0)
        let script = try buildLaunchScript(
            directoryPath: "/tmp/proj",
            layout: .full,
            panesBySlot: [0: p]
        )
        #expect(script.contains("input text \"npm start\" to term0"))
    }

    // MARK: - Path resolution (unchanged helpers)

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
