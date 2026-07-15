import AppKit

/// Pasteboard → temp PNG plumbing for the agent tab's image paste.
enum AgentImagePaste {
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"]

    /// PNG data from the pasteboard: direct bitmap (png/tiff) or an image file URL.
    static func pngData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) { return png }
        if let tiff = pasteboard.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff) {
            return rep.representation(using: .png, properties: [:])
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let imageURL = urls.first(where: { imageExtensions.contains($0.pathExtension.lowercased()) }),
           let data = try? Data(contentsOf: imageURL),
           let rep = NSBitmapImageRep(data: data) {
            return rep.representation(using: .png, properties: [:])
        }
        return nil
    }

    static func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-agent-images-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func saveTempImage(_ data: Data, in dir: URL) -> URL? {
        let url = dir.appendingPathComponent("image-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    static func cleanup(dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }
}
