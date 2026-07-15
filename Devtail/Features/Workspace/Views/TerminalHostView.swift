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

    func makeNSView(context: Context) -> NSView {
        terminalView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
