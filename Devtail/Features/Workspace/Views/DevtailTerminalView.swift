//
//  DevtailTerminalView.swift
//  Devtail
//
//  Base class for every terminal view in the app: adds copy-on-select and
//  mouse-hide-while-typing behavior on top of SwiftTerm's LocalProcessTerminalView.
//  `class`, not `final` — ReadOnlyLocalProcessTerminalView and AgentTerminalView
//  both extend it so those flags (and the appearance applier) reach every
//  terminal variant through one hierarchy.
//
//  `keyDown` is `public` on MacTerminalView, not `open`, so it cannot be
//  overridden here. Every keyboard path funnels through the `open` choke
//  point `send(source:data:)` before reaching the PTY, so mouse-hide is
//  wired there instead — see SwiftTermEngine.swift's ReadOnlyLocalProcessTerminalView
//  doc comment for the fuller rationale (same funnel, different concern).
//
//  NOTE: SwiftTerm has two distinct `send(source:data:)` methods — one on
//  `MacTerminalView` taking `source: Terminal` (a self-delegate path not
//  used by `LocalProcessTerminalView`), and the one actually overridden
//  below on `MacLocalTerminalView` taking `source: TerminalView` (the
//  `TerminalViewDelegate` conformance that forwards typed input to the
//  PTY). Only the latter is the real per-keystroke choke point here.
//

import AppKit
import SwiftTerm

class DevtailTerminalView: LocalProcessTerminalView {
    /// When true, an active text selection is copied to the pasteboard
    /// automatically (no explicit Cmd-C needed) — mirrors common terminal
    /// emulator behavior (iTerm2, Ghostty).
    var copyOnSelect = false
    /// When true, the mouse cursor hides on keystroke, matching the
    /// "hide mouse while typing" behavior from Javier's Ghostty config.
    var hideMouseWhileTyping = false

    /// Pure decision extracted from `selectionChanged` so it's testable
    /// without simulating SwiftTerm's live selection state.
    static func shouldCopy(copyOnSelect: Bool, selection: String?) -> Bool {
        guard copyOnSelect, let selection, !selection.isEmpty else { return false }
        return true
    }

    override func selectionChanged(source: Terminal) {
        super.selectionChanged(source: source)
        let selection = getSelection()
        guard Self.shouldCopy(copyOnSelect: copyOnSelect, selection: selection), let text = selection else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    override func send(source: TerminalView, data: ArraySlice<UInt8>) {
        if hideMouseWhileTyping {
            NSCursor.setHiddenUntilMouseMoves(true)
        }
        super.send(source: source, data: data)
    }
}
