//
//  VSCodeLauncherTests.swift
//  DevtailTests
//
//  Tests for VSCodeLauncher using the resolveAppURL closure seam.
//  The real NSWorkspace.open path is not tested at unit level (integration only).
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("VSCodeLauncher")
struct VSCodeLauncherTests {

    @Test("open throws projectHasNoDirectory for empty directoryPath")
    func openEmptyPath() async {
        var launcher = VSCodeLauncher()
        launcher.resolveAppURL = { _ in URL(string: "file:///Applications/VSCode.app") }

        await #expect(throws: VSCodeLauncherError.projectHasNoDirectory) {
            try await launcher.open(directoryPath: "", bookmark: nil)
        }
    }

    @Test("open throws projectHasNoDirectory for whitespace-only directoryPath")
    func openWhitespacePath() async {
        var launcher = VSCodeLauncher()
        launcher.resolveAppURL = { _ in URL(string: "file:///Applications/VSCode.app") }

        await #expect(throws: VSCodeLauncherError.projectHasNoDirectory) {
            try await launcher.open(directoryPath: "   ", bookmark: nil)
        }
    }

    @Test("open throws vscodeNotInstalled when resolveAppURL returns nil")
    func openVSCodeNotInstalled() async {
        var launcher = VSCodeLauncher()
        launcher.resolveAppURL = { _ in nil }

        await #expect(throws: VSCodeLauncherError.vscodeNotInstalled) {
            try await launcher.open(directoryPath: "/Users/dev/myproject", bookmark: nil)
        }
    }
}
