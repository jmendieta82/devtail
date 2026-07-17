import SwiftUI

/// Maps a filename to an SF Symbol + tint for the file tree, so entries read
/// by type at a glance instead of a flat sheet of identical doc icons.
/// Pure and case-insensitive; unknown extensions fall back to a neutral doc.
enum FileIconMap {
    struct Icon {
        let symbol: String
        let color: Color
    }

    static let folder = Icon(symbol: "folder.fill", color: Color(red: 0.55, green: 0.72, blue: 0.95))
    static let genericFile = Icon(symbol: "doc", color: Color(nsColor: .tertiaryLabelColor))

    static func icon(for filename: String) -> Icon {
        let name = filename.lowercased()

        // Env files: exact `.env` or an `.env.*` variant.
        if name == ".env" || name.hasPrefix(".env.") {
            return Icon(symbol: "key.fill", color: Color(red: 0.96, green: 0.77, blue: 0.35))
        }

        // Exact names first (dotfiles / well-known files carry no extension).
        switch name {
        case ".gitignore", ".gitattributes", ".git":
            return Icon(symbol: "arrow.triangle.branch", color: Color(red: 0.94, green: 0.42, blue: 0.31))
        case "package.json", "package-lock.json":
            return Icon(symbol: "shippingbox.fill", color: Color(red: 0.80, green: 0.33, blue: 0.29))
        case "dockerfile", "docker-compose.yml", "docker-compose.yaml":
            return Icon(symbol: "cube.box.fill", color: Color(red: 0.36, green: 0.55, blue: 0.90))
        case "readme.md", "readme":
            return Icon(symbol: "book.fill", color: Color(red: 0.55, green: 0.72, blue: 0.95))
        case ".ds_store":
            return genericFile
        default:
            break
        }

        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":
            return Icon(symbol: "swift", color: Color(red: 0.94, green: 0.42, blue: 0.31))
        case "ts", "tsx":
            return Icon(symbol: "chevron.left.forwardslash.chevron.right", color: Color(red: 0.30, green: 0.55, blue: 0.90))
        case "js", "jsx", "mjs", "cjs":
            return Icon(symbol: "chevron.left.forwardslash.chevron.right", color: Color(red: 0.96, green: 0.80, blue: 0.35))
        case "json":
            return Icon(symbol: "curlybraces", color: Color(red: 0.85, green: 0.70, blue: 0.35))
        case "md", "markdown", "mdown":
            return Icon(symbol: "text.alignleft", color: Color(red: 0.60, green: 0.66, blue: 0.75))
        case "html", "htm":
            return Icon(symbol: "chevron.left.forwardslash.chevron.right", color: Color(red: 0.90, green: 0.45, blue: 0.30))
        case "css", "scss", "sass", "less":
            return Icon(symbol: "paintbrush.fill", color: Color(red: 0.45, green: 0.60, blue: 0.90))
        case "yml", "yaml", "toml", "ini", "conf", "config":
            return Icon(symbol: "gearshape.fill", color: Color(red: 0.60, green: 0.66, blue: 0.75))
        case "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic":
            return Icon(symbol: "photo.fill", color: Color(red: 0.55, green: 0.78, blue: 0.60))
        case "svg":
            return Icon(symbol: "photo.fill", color: Color(red: 0.90, green: 0.60, blue: 0.40))
        case "pdf":
            return Icon(symbol: "doc.richtext.fill", color: Color(red: 0.90, green: 0.35, blue: 0.30))
        case "zip", "tar", "gz", "tgz", "rar", "7z":
            return Icon(symbol: "doc.zipper", color: Color(red: 0.70, green: 0.65, blue: 0.55))
        case "sh", "bash", "zsh", "fish":
            return Icon(symbol: "terminal.fill", color: Color(red: 0.55, green: 0.75, blue: 0.55))
        case "py":
            return Icon(symbol: "chevron.left.forwardslash.chevron.right", color: Color(red: 0.35, green: 0.60, blue: 0.80))
        case "lock":
            return Icon(symbol: "lock.fill", color: Color(nsColor: .tertiaryLabelColor))
        default:
            return genericFile
        }
    }
}
