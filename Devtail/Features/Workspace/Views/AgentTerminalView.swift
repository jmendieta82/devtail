import AppKit
import SwiftTerm
import os.log

/// Interactive terminal for the agent tab. Overrides paste so images land as
/// bracketed-pasted temp-file paths (the agent TUI renders them as [Image #N]);
/// plain text falls through to SwiftTerm's normal paste. Also accepts file
/// drops: file promises (the macOS screenshot floating thumbnail) materialize
/// into the same temp dir, plain file URLs are sent as-is — either way the
/// path reaches the terminal through the same bracketed-paste wire format.
final class AgentTerminalView: DevtailTerminalView {
    private var imageDir: URL?

    /// Promise materialization runs off-main; completions hop back to
    /// MainActor before touching the terminal.
    private static let promiseQueue = OperationQueue()

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForFileDrops()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForFileDrops()
    }

    private func registerForFileDrops() {
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes(promiseTypes + [.fileURL])
    }

    override func paste(_ sender: Any) {
        if let png = AgentImagePaste.pngData(from: NSPasteboard.general),
           let url = AgentImagePaste.saveTempImage(png, in: ensureImageDir()) {
            sendBracketedPath(url.path)
            return
        }
        super.paste(sender)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canRead = sender.draggingPasteboard.canReadObject(
            forClasses: [NSFilePromiseReceiver.self, NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return canRead ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            let dir = ensureImageDir()
            for receiver in receivers {
                receiver.receivePromisedFiles(atDestination: dir, options: [:], operationQueue: Self.promiseQueue) { [weak self] url, error in
                    if let error {
                        Log.files.warning("File promise materialization failed: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    Task { @MainActor in
                        self?.sendBracketedPath(url.path)
                    }
                }
            }
            return true
        }
        let urls = AgentFileDrop.fileURLs(from: pasteboard)
        guard !urls.isEmpty else { return false }
        for url in urls {
            sendBracketedPath(url.path)
        }
        return true
    }

    /// Hand-rolled bracketed-paste wrap shared by paste and drop: SwiftTerm's
    /// insertText(_:replacementRange:isPaste:) overload is internal to the
    /// SwiftTerm module, so we replicate its paste path (MacTerminalView
    /// non-kitty branch) with public API only. If the running program never
    /// enabled mode 2004, the path is sent unwrapped instead of leaking
    /// escape sequences.
    private func sendBracketedPath(_ path: String) {
        let bracketed = getTerminal().bracketedPasteMode
        if bracketed { send(data: EscapeSequences.bracketedPasteStart[0...]) }
        send(txt: path)
        if bracketed { send(data: EscapeSequences.bracketedPasteEnd[0...]) }
    }

    private func ensureImageDir() -> URL {
        if let imageDir { return imageDir }
        let dir = AgentImagePaste.makeTempDir()
        imageDir = dir
        return dir
    }

    func cleanupImages() {
        if let imageDir { AgentImagePaste.cleanup(dir: imageDir) }
        imageDir = nil
    }
}
