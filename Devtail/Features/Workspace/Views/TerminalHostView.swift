//
//  TerminalHostView.swift
//  Devtail
//
//  Bridges a session's retained NSView into SwiftUI. The representable may be
//  recreated freely by SwiftUI — the underlying NSView instance persists in
//  the holder, so scrollback and the PTY survive.
//

import AppKit
import SwiftTerm
import SwiftUI

/// Contract: when `isActive` is true, this view grabs first responder so
/// keystrokes reach its PTY. When `isActive` is false AND this view (or a
/// descendant, e.g. a SwiftTerm subview promoted to key focus) currently owns
/// first responder, it resigns — otherwise an inactive, hidden terminal keeps
/// the keyboard and steals typing from whatever is now visible (e.g. the
/// workspace settings form).
///
/// Also re-applies `TerminalAppearance` on every update — since ALL terminal
/// views stay permanently mounted (retention model, see WorkspaceRootView),
/// this `updateNSView` pass is what makes a settings change reach every live
/// terminal, not just newly created ones. The Coordinator (not @State — this
/// is a representable) holds the last-applied token so unrelated SwiftUI
/// updates don't redundantly rebuild colors/font/cursor on every render.
struct TerminalHostView: NSViewRepresentable {
    @Environment(AppSettings.self) private var settings
    let terminalView: NSView
    var isActive: Bool = false

    func makeNSView(context: Context) -> NSView { terminalView }

    func updateNSView(_ nsView: NSView, context: Context) {
        let appearance = TerminalAppearance(settings: settings)
        if appearance.token != context.coordinator.lastAppliedToken, let terminalView = nsView as? TerminalView {
            appearance.apply(to: terminalView)
            context.coordinator.lastAppliedToken = appearance.token
        }

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

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastAppliedToken: String?
    }
}
