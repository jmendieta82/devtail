import SwiftUI

/// Green dot indicator for active workspaces.
/// Universal "live" semantic — kept green regardless of the app accent.
struct ActivityDot: View {
    let isActive: Bool

    var body: some View {
        if isActive {
            Circle()
                .fill(Color(red: 0.298, green: 0.851, blue: 0.392))
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
