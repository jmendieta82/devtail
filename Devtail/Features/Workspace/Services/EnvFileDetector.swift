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
    /// A file is env-editable when its last path component, lowercased,
    /// starts with ".env" — this covers `.env`, `.env.local`,
    /// `.env.development`, etc., but not files that merely contain "env"
    /// elsewhere in the name (`whatever.env`, `environment.ts`).
    static func isEnvFile(path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        return name.hasPrefix(".env")
    }
}
