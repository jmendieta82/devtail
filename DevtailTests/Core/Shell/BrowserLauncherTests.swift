//
//  BrowserLauncherTests.swift
//  DevtailTests
//
//  Tests for BrowserLauncher.open(_:) return value.
//  We assert the Bool contract only — NSWorkspace side effects require
//  a real UI session and are not testable at unit level.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("BrowserLauncher")
struct BrowserLauncherTests {

    private let launcher = BrowserLauncher()

    @Test("open returns true for valid http URL")
    func openValidHttp() {
        #expect(launcher.open(urlString: "http://localhost:3000") == true)
    }

    @Test("open returns true for valid https URL")
    func openValidHttps() {
        #expect(launcher.open(urlString: "https://example.com") == true)
    }

    @Test("open returns false for empty string")
    func openEmpty() {
        #expect(launcher.open(urlString: "") == false)
    }

    @Test("open returns false for whitespace-only string")
    func openWhitespace() {
        #expect(launcher.open(urlString: "   ") == false)
    }

    @Test("open returns false for non-URL string")
    func openNotAURL() {
        #expect(launcher.open(urlString: "not a url") == false)
    }

    @Test("open returns false for file:// scheme")
    func openFileScheme() {
        #expect(launcher.open(urlString: "file:///etc/passwd") == false)
    }

    @Test("open returns false for mailto: scheme")
    func openMailtoScheme() {
        #expect(launcher.open(urlString: "mailto:foo@bar.com") == false)
    }
}
