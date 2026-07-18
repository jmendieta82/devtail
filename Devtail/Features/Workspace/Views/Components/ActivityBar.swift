import SwiftUI

/// VS Code-style icon rail: switches what the side panel shows.
struct ActivityBar: View {
    let session: WorkspaceSession

    var body: some View {
        VStack(spacing: DevtailTokens.Spacing.gapSmall) {
            ForEach(SidePanelView.allCases, id: \.self) { view in
                Button {
                    session.sidePanel = view
                } label: {
                    Image(systemName: view.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(session.sidePanel == view
                            ? DevtailTokens.Colors.accentPrimary
                            : DevtailTokens.Colors.textTertiary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.icon)
                .help(view.help)
            }

            Button {
                session.selectedTab = .tasks
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 16))
                    .foregroundStyle(session.selectedTab == .tasks
                        ? DevtailTokens.Colors.accentPrimary
                        : DevtailTokens.Colors.textTertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.icon)
            .help("Tasks")

            Spacer()

            Button {
                session.selectedTab = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(session.selectedTab == .settings
                        ? DevtailTokens.Colors.accentPrimary
                        : DevtailTokens.Colors.textTertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.icon)
            .help("Project settings")
        }
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .frame(width: 48)
    }
}
