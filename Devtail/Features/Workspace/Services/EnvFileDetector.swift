//
//  EnvFileDetector.swift
//  Devtail
//
//  Pure helper deciding which files become editable: the .env family
//  (.env, .env.local, .env.development, ...). Everything else in the
//  workspace viewer stays read-only.
//

import Foundation

enum EnvFileDetector {
    /// A file is env-editable when its last path component, lowercased, is
    /// exactly ".env" or starts with ".env." — this covers `.env`,
    /// `.env.local`, `.env.development`, etc., but not files that merely
    /// start with the same four characters (`.environment`) or contain "env"
    /// elsewhere in the name (`whatever.env`).
    static func isEnvFile(path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        return name == ".env" || name.hasPrefix(".env.")
    }
}
