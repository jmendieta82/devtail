import AppKit

/// Pasteboard → file URLs for the agent tab's drag & drop. Any file type is
/// accepted (dragging a .swift or a log into the agent is useful, not just
/// images); non-file drag content yields nothing.
enum AgentFileDrop {
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return []
        }
        return urls
    }
}
