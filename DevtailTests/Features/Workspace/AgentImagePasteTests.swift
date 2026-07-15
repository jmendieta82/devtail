import AppKit
import Testing
@testable import Devtail

@MainActor
struct AgentImagePasteTests {
    private func makePasteboard() -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("devtail-test-\(UUID().uuidString)"))
        pb.clearContents()
        return pb
    }

    private func tinyPNG() -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func extractsPNGFromBitmapPasteboard() {
        let pb = makePasteboard()
        pb.setData(tinyPNG(), forType: .png)
        #expect(AgentImagePaste.pngData(from: pb) != nil)
    }

    @Test func extractsPNGFromTIFFPasteboard() {
        let pb = makePasteboard()
        let image = NSImage(data: tinyPNG())!
        pb.setData(image.tiffRepresentation!, forType: .tiff)
        #expect(AgentImagePaste.pngData(from: pb) != nil)
    }

    @Test func extractsPNGFromImageFileURL() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-imgtest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("shot.png")
        try tinyPNG().write(to: file)
        let pb = makePasteboard()
        pb.writeObjects([file as NSURL])
        #expect(AgentImagePaste.pngData(from: pb) != nil)
    }

    @Test func textOnlyPasteboardYieldsNil() {
        let pb = makePasteboard()
        pb.setString("hola", forType: .string)
        #expect(AgentImagePaste.pngData(from: pb) == nil)
    }

    @Test func nonImageFileURLYieldsNil() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-imgtest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("notes.txt")
        try Data("x".utf8).write(to: file)
        let pb = makePasteboard()
        pb.writeObjects([file as NSURL])
        #expect(AgentImagePaste.pngData(from: pb) == nil)
    }

    @Test func saveAndCleanupTempImages() {
        let dir = AgentImagePaste.makeTempDir()
        let url = AgentImagePaste.saveTempImage(tinyPNG(), in: dir)
        #expect(url != nil)
        #expect(FileManager.default.fileExists(atPath: url!.path))
        #expect(url!.pathExtension == "png")
        AgentImagePaste.cleanup(dir: dir)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }
}
