//
//  ProjectStoreLaunchTests.swift
//  DevtailTests
//
//  Tests for ProjectStore's launch + VSCode scenarios using mock launchers.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("ProjectStore — launch and VSCode")
struct ProjectStoreLaunchTests {

    private func makeStore(
        projectRepo: MockProjectRepository? = nil,
        launcher: MockWorkspaceLauncher? = nil,
        vscodeLauncher: MockVSCodeLauncher? = nil,
        browserLauncher: MockBrowserLauncher? = nil
    ) -> (ProjectStore, MockWorkspaceLauncher, MockVSCodeLauncher, MockBrowserLauncher) {
        let workspaceLauncher = launcher ?? MockWorkspaceLauncher()
        let vscode = vscodeLauncher ?? MockVSCodeLauncher()
        let browser = browserLauncher ?? MockBrowserLauncher()
        let store = ProjectStore(
            repository: projectRepo ?? MockProjectRepository(),
            quickLinkRepository: MockQuickLinkRepository(),
            workspacePaneRepository: MockWorkspacePaneRepository(),
            launcher: workspaceLauncher,
            vscodeLauncher: vscode,
            browserLauncher: browser
        )
        return (store, workspaceLauncher, vscode, browser)
    }

    private func makeProject(name: String = "Test") -> Project {
        let project = Project(name: name)
        project.directoryPath = "/Users/dev/\(name.lowercased())"
        return project
    }

    private func makeFrontendPane(
        label: String = "frontend",
        url: String? = "http://localhost:3000",
        order: Int = 0,
        project: Project? = nil
    ) -> WorkspacePane {
        let pane = WorkspacePane(
            label: label,
            relativeCwd: "frontend",
            command: "npm run dev",
            order: order,
            layoutSlot: 0,
            isFrontend: true,
            localhostUrl: url,
            project: project
        )
        return pane
    }

    private func makeBackendPane(order: Int = 1, project: Project? = nil) -> WorkspacePane {
        WorkspacePane(
            label: "backend",
            relativeCwd: "backend",
            command: "python manage.py runserver",
            order: order,
            layoutSlot: 1,
            isFrontend: false,
            localhostUrl: nil,
            project: project
        )
    }

    // MARK: - launchWorkspace + pane-level browser

    @Test("store iterates panes and calls browser.open for each frontend pane with valid URL")
    func launchIteratesPanesAndOpensBrowserForFrontendOnes() async {
        let (store, _, _, browser) = makeStore()
        let project = makeProject(name: "Monorepo")
        let frontendPane = makeFrontendPane(url: "http://localhost:4200", order: 0, project: project)
        let backendPane = makeBackendPane(order: 1, project: project)
        project.workspacePanes.append(contentsOf: [frontendPane, backendPane])

        store.launchWorkspace(for: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(browser.urlStrings == ["http://localhost:4200"])
    }

    @Test("multiple frontend panes produce multiple browser tabs")
    func launchMultipleFrontendPanesProduceMultipleTabs() async {
        let (store, _, _, browser) = makeStore()
        let project = makeProject(name: "Fullstack")
        let pane1 = makeFrontendPane(label: "app", url: "http://localhost:4200", order: 0, project: project)
        let pane2 = makeFrontendPane(label: "storybook", url: "http://localhost:6006", order: 1, project: project)
        project.workspacePanes.append(contentsOf: [pane1, pane2])

        store.launchWorkspace(for: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(browser.urlStrings.count == 2)
        #expect(browser.urlStrings.contains("http://localhost:4200"))
        #expect(browser.urlStrings.contains("http://localhost:6006"))
    }

    @Test("non-frontend panes do not trigger browser even when other panes exist")
    func launchNonFrontendPanesDoNotTriggerBrowser() async {
        let (store, launcher, _, browser) = makeStore()
        let project = makeProject(name: "Backend")
        let backendPane = makeBackendPane(order: 0, project: project)
        project.workspacePanes.append(backendPane)

        store.launchWorkspace(for: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(browser.urlStrings.isEmpty)
        #expect(launcher.launchCallCount == 1)
    }

    @Test("frontend pane with nil localhostUrl is skipped silently")
    func launchFrontendPaneNilURLSkipped() async {
        let (store, launcher, _, browser) = makeStore()
        let project = makeProject(name: "Frontend")
        let pane = makeFrontendPane(url: nil, order: 0, project: project)
        project.workspacePanes.append(pane)

        store.launchWorkspace(for: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(browser.urlStrings.isEmpty)
        #expect(launcher.launchCallCount == 1)
    }

    @Test("frontend pane with empty localhostUrl is skipped silently")
    func launchFrontendPaneEmptyURLSkipped() async {
        let (store, launcher, _, browser) = makeStore()
        let project = makeProject(name: "Frontend")
        let pane = makeFrontendPane(url: "", order: 0, project: project)
        project.workspacePanes.append(pane)

        store.launchWorkspace(for: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(browser.urlStrings.isEmpty)
        #expect(launcher.launchCallCount == 1)
    }

    @Test("browser open happens before Ghostty Task — Ghostty throwing still opens browser")
    func launchGhosttyThrowsButBrowserStillCalled() async {
        let workspaceLauncher = MockWorkspaceLauncher()
        workspaceLauncher.errorToThrow = WorkspaceLauncherError.ghosttyNotInstalled
        let (store, _, _, browser) = makeStore(launcher: workspaceLauncher)

        let project = makeProject(name: "Frontend")
        let pane = makeFrontendPane(url: "http://localhost:4200", order: 0, project: project)
        project.workspacePanes.append(pane)

        store.launchWorkspace(for: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(browser.urlStrings == ["http://localhost:4200"])
        #expect(store.lastError as? WorkspaceLauncherError == .ghosttyNotInstalled)
    }

    @Test("project with no panes does not call browser")
    func launchProjectNoPanesNoBrowserCall() async {
        let (store, launcher, _, browser) = makeStore()
        let project = makeProject(name: "Empty")

        store.launchWorkspace(for: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(browser.urlStrings.isEmpty)
        #expect(launcher.launchCallCount == 1)
    }

    // MARK: - openInVSCode

    @Test("openInVSCode with empty directoryPath sets lastError to projectHasNoDirectory")
    func openInVSCodeEmptyDirectory() async {
        let vscode = MockVSCodeLauncher()
        vscode.errorToThrow = VSCodeLauncherError.projectHasNoDirectory
        let (store, _, _, _) = makeStore(vscodeLauncher: vscode)

        let project = Project(name: "NoDir")
        // directoryPath defaults to ""

        store.openInVSCode(project: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(store.lastError as? VSCodeLauncherError == .projectHasNoDirectory)
    }

    @Test("openInVSCode with valid directory calls vscode launcher with that path")
    func openInVSCodeValidDirectory() async {
        let (store, _, vscode, _) = makeStore()
        let project = Project(name: "MyProject")
        project.directoryPath = "/Users/dev/myproject"

        store.openInVSCode(project: project)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(vscode.openCallCount == 1)
        #expect(vscode.lastDirectoryPath == "/Users/dev/myproject")
        #expect(store.lastError == nil)
    }
}
