//
//  MockBrowserLauncher.swift
//  DevtailTests
//
//  Test double for BrowserLauncherProtocol.
//  Records every URL string passed to open(_:) so tests can assert
//  "browser was called" without depending on NSWorkspace side effects.
//

import Foundation
@testable import Devtail

@MainActor
final class MockBrowserLauncher: BrowserLauncherProtocol {
    var urlStrings: [String] = []

    @discardableResult
    func open(urlString: String) -> Bool {
        urlStrings.append(urlString)
        return true
    }
}
