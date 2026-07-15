/// File extension → highlight.js language name. Unknown → nil (engine auto-detect).
enum CodeLanguageMap {
    private static let map: [String: String] = [
        "swift": "swift", "ts": "typescript", "tsx": "typescript",
        "js": "javascript", "jsx": "javascript", "mjs": "javascript",
        "py": "python", "rb": "ruby", "go": "go", "rs": "rust",
        "java": "java", "kt": "kotlin", "cs": "csharp",
        "json": "json", "yml": "yaml", "yaml": "yaml", "toml": "ini",
        "md": "markdown", "sh": "bash", "zsh": "bash", "bash": "bash",
        "html": "xml", "htm": "xml", "xml": "xml", "plist": "xml",
        "css": "css", "scss": "scss", "sql": "sql",
        "c": "c", "h": "c", "cpp": "cpp", "hpp": "cpp", "m": "objectivec",
        "dockerfile": "dockerfile", "gradle": "gradle", "graphql": "graphql",
    ]

    static func language(forExtension ext: String) -> String? {
        map[ext.lowercased()]
    }
}
