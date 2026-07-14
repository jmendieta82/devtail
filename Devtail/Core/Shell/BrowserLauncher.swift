//
//  BrowserLauncher.swift
//  Devtail
//
//  Opens a URL in the user's default browser. Fully synchronous, fire-and-
//  forget. Returns a Bool so tests can assert "valid URL → open attempted"
//  without observing LaunchServices side effects.
//

import AppKit
import Foundation

// MARK: - Protocol

@MainActor
protocol BrowserLauncherProtocol {
    /// Opens `urlString` in the user's default browser.
    /// - Returns: `true` if the URL is valid (http/https) and the open call
    ///   was dispatched; `false` if the string was not a valid http/https URL.
    ///   Callers treat `false` as "skip silently" — no error is surfaced.
    @discardableResult
    func open(urlString: String) -> Bool
}

// MARK: - Implementation

@MainActor
struct BrowserLauncher: BrowserLauncherProtocol {
    @discardableResult
    func open(urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        NSWorkspace.shared.open(url)
        return true
    }
}
