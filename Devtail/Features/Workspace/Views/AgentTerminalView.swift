import AppKit
import SwiftTerm

/// Interactive terminal for the agent tab. Overrides paste so images land as
/// bracketed-pasted temp-file paths (the agent TUI renders them as [Image #N]);
/// plain text falls through to SwiftTerm's normal paste.
final class AgentTerminalView: LocalProcessTerminalView {
    private var imageDir: URL?

    override func paste(_ sender: Any) {
        if let png = AgentImagePaste.pngData(from: NSPasteboard.general) {
            let dir: URL
            if let existing = imageDir {
                dir = existing
            } else {
                dir = AgentImagePaste.makeTempDir()
                imageDir = dir
            }
            if let url = AgentImagePaste.saveTempImage(png, in: dir) {
                // Hand-rolled bracketed-paste wrap: SwiftTerm's
                // insertText(_:replacementRange:isPaste:) overload is internal to
                // the SwiftTerm module, so we replicate its paste path
                // (MacTerminalView non-kitty branch) with public API only. If the
                // running program never enabled mode 2004, the path is sent
                // unwrapped instead of leaking escape sequences.
                let bracketed = getTerminal().bracketedPasteMode
                if bracketed { send(data: EscapeSequences.bracketedPasteStart[0...]) }
                send(txt: url.path)
                if bracketed { send(data: EscapeSequences.bracketedPasteEnd[0...]) }
                return
            }
        }
        super.paste(sender)
    }

    func cleanupImages() {
        if let imageDir { AgentImagePaste.cleanup(dir: imageDir) }
        imageDir = nil
    }
}
