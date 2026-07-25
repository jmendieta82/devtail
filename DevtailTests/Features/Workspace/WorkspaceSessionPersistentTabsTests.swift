//
//  WorkspaceSessionPersistentTabsTests.swift
//  DevtailTests
//
//  TDD for WorkspaceSession.openTasks/closeTasks and openSettings/
//  closeSettings: tasks and settings tabs must stay in the tab row once
//  opened, until the user closes them with their X — switching tabs never
//  removes them. Mirrors WorkspaceSessionOpenFilesTests's open/close shape.
//

import Foundation
import SwiftData
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionPersistentTabsTests {
    // MARK: - Helpers

    private func project(_ name: String) -> Project {
        let p = Project(name: name)
        p.directoryPath = "/tmp/\(name)"
        return p
    }

    /// Creates a WorkspaceSession with mocked dependencies, same pattern as
    /// WorkspaceSessionOpenFilesTests.makeSession().
    private func makeSession() -> WorkspaceSession {
        let engine = MockTerminalEngine()
        let defaults = UserDefaults(suiteName: "WorkspaceSessionPersistentTabsTests-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        let holder = WorkspaceSessionsHolder(engine: engine, browserLauncher: MockBrowserLauncher(), settings: settings)
        let p = project("test")
        return holder.openSession(for: p)
    }

    // MARK: - Tasks

    @Test func openTasksSetsFlagAndSelects() {
        let s = makeSession()
        s.openTasks()
        #expect(s.isTasksTabOpen)
        #expect(s.selectedTab == .tasks)
    }

    @Test func switchingAwayFromTasksKeepsItOpen() {
        let s = makeSession()
        s.openTasks()
        s.selectedTab = s.firstAgentTab
        #expect(s.isTasksTabOpen)
    }

    @Test func closeTasksClearsFlagAndFallsBackWhenSelected() {
        let s = makeSession()
        s.openTasks()
        s.closeTasks()
        #expect(!s.isTasksTabOpen)
        #expect(s.selectedTab == s.firstAgentTab)
    }

    @Test func closeTasksLeavesSelectionUntouchedWhenNotSelected() {
        let s = makeSession()
        s.openTasks()
        s.selectedTab = s.firstAgentTab
        s.closeTasks()
        #expect(!s.isTasksTabOpen)
        #expect(s.selectedTab == s.firstAgentTab)
    }

    @Test func openTasksIsIdempotentAndReselects() {
        let s = makeSession()
        s.openTasks()
        s.selectedTab = s.firstAgentTab
        s.openTasks()
        #expect(s.isTasksTabOpen)
        #expect(s.selectedTab == .tasks)
    }

    // MARK: - Settings

    @Test func openSettingsSetsFlagAndSelects() {
        let s = makeSession()
        s.openSettings()
        #expect(s.isSettingsTabOpen)
        #expect(s.selectedTab == .settings)
    }

    @Test func switchingAwayFromSettingsKeepsItOpen() {
        let s = makeSession()
        s.openSettings()
        s.selectedTab = s.firstAgentTab
        #expect(s.isSettingsTabOpen)
    }

    @Test func closeSettingsClearsFlagAndFallsBackWhenSelected() {
        let s = makeSession()
        s.openSettings()
        s.closeSettings()
        #expect(!s.isSettingsTabOpen)
        #expect(s.selectedTab == s.firstAgentTab)
    }

    @Test func closeSettingsLeavesSelectionUntouchedWhenNotSelected() {
        let s = makeSession()
        s.openSettings()
        s.selectedTab = s.firstAgentTab
        s.closeSettings()
        #expect(!s.isSettingsTabOpen)
        #expect(s.selectedTab == s.firstAgentTab)
    }

    @Test func openSettingsIsIdempotentAndReselects() {
        let s = makeSession()
        s.openSettings()
        s.selectedTab = s.firstAgentTab
        s.openSettings()
        #expect(s.isSettingsTabOpen)
        #expect(s.selectedTab == .settings)
    }
}
