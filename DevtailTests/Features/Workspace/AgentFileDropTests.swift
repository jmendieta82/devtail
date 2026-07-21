import AppKit
import Testing
@testable import Devtail

@MainActor
struct AgentFileDropTests {
    private func makePasteboard() -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("devtail-test-\(UUID().uuidString)"))
        pb.clearContents()
        return pb
    }

    private func makeTempFiles(_ names: [String]) throws -> (dir: URL, files: [URL]) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-droptest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let files = try names.map { name -> URL in
            let file = dir.appendingPathComponent(name)
            try Data("x".utf8).write(to: file)
            return file
        }
        return (dir, files)
    }

    @Test func extractsFileURL() throws {
        let (dir, files) = try makeTempFiles(["shot.png"])
        defer { try? FileManager.default.removeItem(at: dir) }
        let pb = makePasteboard()
        pb.writeObjects([files[0] as NSURL])
        #expect(AgentFileDrop.fileURLs(from: pb) == files)
    }

    @Test func preservesMultipleFileURLsInOrder() throws {
        let (dir, files) = try makeTempFiles(["a.swift", "b.log", "c.png"])
        defer { try? FileManager.default.removeItem(at: dir) }
        let pb = makePasteboard()
        pb.writeObjects(files.map { $0 as NSURL })
        #expect(AgentFileDrop.fileURLs(from: pb) == files)
    }

    @Test func nonFileContentYieldsEmpty() {
        let pb = makePasteboard()
        pb.setString("hola", forType: .string)
        #expect(AgentFileDrop.fileURLs(from: pb).isEmpty)
    }

    @Test func remoteURLYieldsEmpty() {
        let pb = makePasteboard()
        pb.writeObjects([URL(string: "https://example.com/shot.png")! as NSURL])
        #expect(AgentFileDrop.fileURLs(from: pb).isEmpty)
    }
}
