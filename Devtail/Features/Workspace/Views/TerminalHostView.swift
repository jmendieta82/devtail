//
//  TerminalHostView.swift
//  Devtail
//
//  Bridges a session's retained NSView into SwiftUI. The representable may be
//  recreated freely by SwiftUI — the underlying NSView instance persists in
//  the holder, so scrollback and the PTY survive.
//

import AppKit
import SwiftUI

/// Contract: when `isActive` is true, this view grabs first responder so
/// keystrokes reach its PTY. When `isActive` is false AND this view (or a
/// descendant, e.g. a SwiftTerm subview promoted to key focus) currently owns
/// first responder, it resigns — otherwise an inactive, hidden terminal keeps
/// the keyboard and steals typing from whatever is now visible (e.g. the
/// workspace settings form).
struct TerminalHostView: NSViewRepresentable {
    let terminalView: NSView
    var isActive: Bool = false

    func makeNSView(context: Context) -> NSView { terminalView }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Defer: updateNSView runs mid view-update; moving key focus inline can warn.
        DispatchQueue.main.async { [weak nsView] in
            guard let nsView, let window = nsView.window else { return }
            if isActive {
                guard window.firstResponder !== nsView else { return }
                window.makeFirstResponder(nsView)
            } else if let responder = window.firstResponder as? NSView,
                      responder.isDescendant(of: nsView) {
                window.makeFirstResponder(nil)
            }
        }
    }
}
