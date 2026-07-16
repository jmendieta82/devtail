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
                .buttonStyle(.plain)
                .help(view.help)
            }
            Spacer()
        }
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .frame(width: 48)
    }
}
