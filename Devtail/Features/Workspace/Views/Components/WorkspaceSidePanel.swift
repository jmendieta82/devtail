import SwiftUI

/// Side panel content, switched by the activity bar.
struct WorkspaceSidePanel: View {
    let session: WorkspaceSession

    var body: some View {
        switch session.sidePanel {
        case .files:
            FileTreeColumn(session: session)
        case .processes:
            processesPanel
        case nil:
            EmptyView()
        }
    }

    private var processesPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                SectionHeader(title: "Processes")
                ForEach(session.supervisor.processes) { process in
                    ProcessCardView(
                        process: process,
                        isSelected: session.selectedTab == .process(process.id),
                        onSelect: {
                            // Never-started processes have no session, hence no tab —
                            // selecting the card must not point at a tab that renders nothing.
                            if process.session != nil { session.selectedTab = .process(process.id) }
                        },
                        onStart: {
                            // Start opens the tab: after start() the session exists,
                            // so selecting immediately shows the live process view.
                            session.supervisor.start(process)
                            session.selectedTab = .process(process.id)
                        },
                        onStop: { session.supervisor.stop(process) },
                        onRestart: { session.supervisor.restart(process) }
                    )
                }
            }
            .padding(DevtailTokens.Spacing.cardPadding)
        }
    }
}
