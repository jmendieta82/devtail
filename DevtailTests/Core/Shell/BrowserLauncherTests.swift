//
//  BrowserLauncherTests.swift
//  DevtailTests
//
//  Tests for BrowserLauncher.open(_:). The NSWorkspace side effect is
//  injected via `opener`, so the suite asserts both the Bool contract and
//  the dispatch — without ever opening a real browser tab.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("BrowserLauncher")
struct BrowserLauncherTests {

    private let launcher = BrowserLauncher(opener: { _ in })

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

    @Test("open dispatches the parsed URL to the opener exactly once")
    func openDispatchesToOpener() {
        var opened: [URL] = []
        let spied = BrowserLauncher(opener: { opened.append($0) })
        spied.open(urlString: "http://localhost:4200")
        #expect(opened == [URL(string: "http://localhost:4200")!])
    }

    @Test("invalid URL never reaches the opener")
    func invalidNeverReachesOpener() {
        var opened: [URL] = []
        let spied = BrowserLauncher(opener: { opened.append($0) })
        spied.open(urlString: "not a url")
        #expect(opened.isEmpty)
    }
}
