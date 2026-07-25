import SwiftUI

/// VS Code-style icon rail: switches what the side panel shows.
struct ActivityBar: View {
    let session: WorkspaceSession

    var body: some View {
        VStack(spacing: DevtailTokens.Spacing.gapSmall) {
            ForEach(SidePanelView.allCases, id: \.self) { view in
                Button {
                    session.sidePanel = (session.sidePanel == view) ? nil : view
                } label: {
                    Image(systemName: view.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(session.sidePanel == view
                            ? DevtailTokens.Colors.accentPrimary
                            : DevtailTokens.Colors.textTertiary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.icon)
                .help(view.help)
            }

            Button {
                session.openTasks()
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 18))
                    .foregroundStyle(session.selectedTab == .tasks
                        ? DevtailTokens.Colors.accentPrimary
                        : DevtailTokens.Colors.textTertiary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.icon)
            .help("Tasks")

            Spacer()

            Button {
                session.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundStyle(session.selectedTab == .settings
                        ? DevtailTokens.Colors.accentPrimary
                        : DevtailTokens.Colors.textTertiary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.icon)
            .help("Project settings")
        }
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .frame(width: 48)
    }
}
