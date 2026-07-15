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

struct TerminalHostView: NSViewRepresentable {
    let terminalView: NSView
    var isActive: Bool = false

    func makeNSView(context: Context) -> NSView { terminalView }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard isActive else { return }
        // Defer: updateNSView runs mid view-update; moving key focus inline can warn.
        DispatchQueue.main.async { [weak nsView] in
            guard let nsView, let window = nsView.window,
                  window.firstResponder !== nsView else { return }
            window.makeFirstResponder(nsView)
        }
    }
}
