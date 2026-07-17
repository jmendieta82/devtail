import SwiftUI

/// Plain button that shows the link (hand) pointer on hover — for the app's
/// icon-only controls (rail, tab chips, tree actions, process cards) so every
/// clickable glyph signals it's clickable. Replaces bare `.buttonStyle(.plain)`
/// on those controls.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .pointerStyle(.link)
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
}
