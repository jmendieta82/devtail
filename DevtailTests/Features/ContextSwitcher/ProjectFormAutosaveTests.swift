//
//  ProjectFormAutosaveTests.swift
//  DevtailTests
//
//  Tests for the pure edit-mode autosave commit decision used by
//  ProjectFormView: valid + changed commits, invalid never commits,
//  unchanged never commits (no redundant writes).
//

import Testing
import Foundation
@testable import Devtail

@Suite("ProjectFormAutosave.shouldCommit")
struct ProjectFormAutosaveTests {

    @Test("Valid and changed name commits")
    func validAndChangedNameCommits() {
        let result = ProjectFormAutosave.shouldCommit(
            trimmedName: "New Name",
            directoryPath: "/Users/dev/project",
            launchTarget: .auto,
            persistedName: "Old Name",
            persistedDirectoryPath: "/Users/dev/project",
            persistedLaunchTarget: .auto
        )
        #expect(result)
    }

    @Test("Valid and changed directory commits")
    func validAndChangedDirectoryCommits() {
        let result = ProjectFormAutosave.shouldCommit(
            trimmedName: "Project",
            directoryPath: "/Users/dev/new-path",
            launchTarget: .auto,
            persistedName: "Project",
            persistedDirectoryPath: "/Users/dev/old-path",
            persistedLaunchTarget: .auto
        )
        #expect(result)
    }

    @Test("Valid and changed launchTarget commits")
    func validAndChangedLaunchTargetCommits() {
        let result = ProjectFormAutosave.shouldCommit(
            trimmedName: "Project",
            directoryPath: "/Users/dev/project",
            launchTarget: .newWindow,
            persistedName: "Project",
            persistedDirectoryPath: "/Users/dev/project",
            persistedLaunchTarget: .auto
        )
        #expect(result)
    }

    @Test("Invalid (empty name) never commits, even if changed")
    func invalidEmptyNameNeverCommits() {
        let result = ProjectFormAutosave.shouldCommit(
            trimmedName: "",
            directoryPath: "/Users/dev/new-path",
            launchTarget: .auto,
            persistedName: "Old Name",
            persistedDirectoryPath: "/Users/dev/project",
            persistedLaunchTarget: .auto
        )
        #expect(!result)
    }

    @Test("Invalid (empty directory) never commits, even if changed")
    func invalidEmptyDirectoryNeverCommits() {
        let result = ProjectFormAutosave.shouldCommit(
            trimmedName: "New Name",
            directoryPath: "",
            launchTarget: .auto,
            persistedName: "Old Name",
            persistedDirectoryPath: "/Users/dev/project",
            persistedLaunchTarget: .auto
        )
        #expect(!result)
    }

    @Test("Valid but unchanged never commits (no redundant write)")
    func validButUnchangedNeverCommits() {
        let result = ProjectFormAutosave.shouldCommit(
            trimmedName: "Project",
            directoryPath: "/Users/dev/project",
            launchTarget: .auto,
            persistedName: "Project",
            persistedDirectoryPath: "/Users/dev/project",
            persistedLaunchTarget: .auto
        )
        #expect(!result)
    }
}
