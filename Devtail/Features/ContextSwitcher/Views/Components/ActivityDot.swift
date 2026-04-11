import SwiftUI

/// Green dot indicator for active workspaces.
/// Designed to overlay on top of a ColorDot.
///
/// Usage:
///     ColorDot(color: project.color)
///         .overlay(alignment: .bottomTrailing) {
///             ActivityDot(isActive: monitor.isActive(projectID: project.id))
///         }
struct ActivityDot: View {
    let isActive: Bool

    var body: some View {
        if isActive {
            Circle()
                .fill(DevtailTokens.Colors.activityGreen)
                .frame(
                    width: DevtailTokens.Sizes.activityDotSize,
                    height: DevtailTokens.Sizes.activityDotSize
                )
                .overlay {
                    Circle()
                        .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5)
                }
        }
    }
}
