import Foundation

enum FileViewerContent: Equatable {
    case text(String, language: String?, highlightable: Bool)
    case binary
    case tooLarge(Int)
    case unreadable(String)
}

/// Loads a file for the read-only viewer with VS Code-style guardrails.
enum FileContentLoader {
    static let highlightByteLimit = 512 * 1024
    static let highlightLineLimit = 10_000
    static let plainByteLimit = 5 * 1024 * 1024

    static func load(path: String) -> FileViewerContent {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return .unreadable(error.localizedDescription)
        }
        if data.count > plainByteLimit { return .tooLarge(data.count) }
        if data.prefix(8192).contains(0) { return .binary }
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            return .binary
        }
        let language = CodeLanguageMap.language(forExtension: url.pathExtension)
        let lineCount = text.lazy.filter { $0 == "\n" }.count + 1
        let highlightable = data.count <= highlightByteLimit && lineCount <= highlightLineLimit
        return .text(text, language: language, highlightable: highlightable)
    }
}
