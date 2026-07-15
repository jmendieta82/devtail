//
//  ProjectStoreLaunchTests.swift
//  DevtailTests
//
//  Tests for ProjectStore's VSCode launch scenarios using mock launchers.
//  Workspace launch (pane spawn, frontend browser opening) moved to
//  ProcessSupervisor / WorkspaceSessionsHolder — see
//  ProcessSupervisorTests / WorkspaceSessionsHolderTests. ProjectStore now
//  only prepares launch state (prepareLaunch); see
//  ProjectStorePrepareLaunchTests.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("ProjectStore — VSCode launch")
struct ProjectStoreLaunchTests {

    private func makeStore(
        projectRepo: MockProjectRepository? = nil,
        vscodeLauncher: MockVSCodeLauncher? = nil,
        browserLauncher: MockBrowserLauncher? = nil
    ) -> (ProjectStore, MockVSCodeLauncher, MockBrowserLauncher) {
        let vscode = vscodeLauncher ?? MockVSCodeLauncher()
        let browser = browserLauncher ?? MockBrowserLauncher()
        let store = ProjectStore(
            repository: projectRepo ?? MockProjectRepository(),
            quickLinkRepository: MockQuickLinkRepository(),
            workspacePaneRepository: MockWorkspacePaneRepository(),
            vscodeLauncher: vscode,
            browserLauncher: browser
        )
        return (store, vscode, browser)
    }

    // MARK: - openInVSCode

    @Test("openInVSCode with empty directoryPath sets lastError to projectHasNoDirectory")
    func openInVSCodeEmptyDirectory() async {
        let vscode = MockVSCodeLauncher()
        vscode.errorToThrow = VSCodeLauncherError.projectHasNoDirectory
        let (store, _, _) = makeStore(vscodeLauncher: vscode)

        let project = Project(name: "NoDir")
        // directoryPath defaults to ""

        store.openInVSCode(project: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(store.lastError as? VSCodeLauncherError == .projectHasNoDirectory)
    }

    @Test("openInVSCode with valid directory calls vscode launcher with that path")
    func openInVSCodeValidDirectory() async {
        let (store, vscode, _) = makeStore()
        let project = Project(name: "MyProject")
        project.directoryPath = "/Users/dev/myproject"

        store.openInVSCode(project: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(vscode.openCallCount == 1)
        #expect(vscode.lastDirectoryPath == "/Users/dev/myproject")
        #expect(store.lastError == nil)
    }
}
