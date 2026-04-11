import SwiftUI

/// Tracks which projects have active Ghostty workspaces.
///
/// Detection strategy:
/// 1. On launch: project ID added to `launchedProjectPaths`
/// 2. On popover open / manual refresh: AppleScript checks working directories
/// 3. NSWorkspace notification: if Ghostty terminates, clear everything
@MainActor @Observable
final class WorkspaceActivityMonitor {

    private(set) var activeProjectIDs: Set<UUID> = []

    private var launchedProjectPaths: [UUID: String] = [:]

    private let ghosttyBundleID = "com.mitchellh.ghostty"

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == self?.ghosttyBundleID else { return }
            Task { @MainActor in
                self?.activeProjectIDs.removeAll()
                self?.launchedProjectPaths.removeAll()
            }
        }
    }

    func markLaunched(projectID: UUID, directoryPath: String) {
        launchedProjectPaths[projectID] = directoryPath
        activeProjectIDs.insert(projectID)
    }

    func refresh() async {
        guard !launchedProjectPaths.isEmpty else { return }
        guard isGhosttyRunning() else {
            activeProjectIDs.removeAll()
            launchedProjectPaths.removeAll()
            return
        }

        var stillActive: Set<UUID> = []
        for (projectID, path) in launchedProjectPaths {
            if await checkWorkspaceActive(directoryPath: path) {
                stillActive.insert(projectID)
            }
        }
        activeProjectIDs = stillActive

        for id in launchedProjectPaths.keys where !stillActive.contains(id) {
            launchedProjectPaths.removeValue(forKey: id)
        }
    }

    func isActive(projectID: UUID) -> Bool {
        activeProjectIDs.contains(projectID)
    }

    // MARK: - Private

    private func isGhosttyRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == ghosttyBundleID
        }
    }

    private func checkWorkspaceActive(directoryPath: String) async -> Bool {
        let script = buildCheckScript(directoryPath: directoryPath)
        return await Task.detached {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let result = appleScript?.executeAndReturnError(&error)
            guard error == nil else { return false }
            return result?.booleanValue ?? false
        }.value
    }

    private func buildCheckScript(directoryPath: String) -> String {
        let escaped = directoryPath.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        tell application "Ghostty"
            if not running then return false
            set matchRoot to "\(escaped)/"
            repeat with tm in every terminal
                set cwd to working directory of tm
                if cwd = "\(escaped)" then return true
                if cwd starts with matchRoot then return true
            end repeat
            return false
        end tell
        """
    }
}
