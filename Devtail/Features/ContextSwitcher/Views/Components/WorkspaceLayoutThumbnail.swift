//
//  WorkspaceLayoutThumbnail.swift
//  Devtail
//
//  Geometric thumbnail that visually represents a WorkspaceLayout. Used in
//  two modes:
//    - Picker mode (slotLabels == nil, onSlotMenu == nil): draws bare rects,
//      no overlays.
//    - Assignment mode (slotLabels and onSlotMenu provided): overlays each
//      rect with a Menu button showing the current label or "—", allowing
//      the user to assign panes to slots.
//
//  The model-level layout fields (Project.layout, WorkspacePane.layoutSlot)
//  remain dormant in the UI as of the LAYOUT picker retirement — this view
//  currently has no production caller (see its #Preview only).
//

import SwiftUI

@MainActor
struct WorkspaceLayoutThumbnail: View {
    let layout: WorkspaceLayout
    let size: CGSize
    /// When provided, labels are shown inside each slot rect. Keyed by slot index.
    var slotLabels: [Int: String]? = nil
    /// When provided, each slot rect gets a Menu overlay. The closure receives
    /// the slot index and returns the menu view as AnyView.
    var onSlotMenu: ((Int) -> AnyView)? = nil

    var body: some View {
        Canvas { context, canvasSize in
            drawLayout(in: context, size: canvasSize)
        }
        .overlay(alignment: .topLeading) {
            if onSlotMenu != nil {
                GeometryReader { geo in
                    menuOverlays(for: geo.size)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Canvas drawing

    private func drawLayout(in context: GraphicsContext, size: CGSize) {
        let gap: CGFloat = 2
        let cornerRadius: CGFloat = 2
        let fillColor = Color(nsColor: .quaternaryLabelColor)

        let rects = slotRects(in: size, gap: gap)
        for rect in rects {
            let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
            context.fill(path, with: .color(fillColor))
        }
    }

    // MARK: - Slot rect geometry

    /// Returns one CGRect per slot, matching the visual layout.
    private func slotRects(in size: CGSize, gap: CGFloat) -> [CGRect] {
        let w = size.width
        let h = size.height

        switch layout {
        case .full:
            return [CGRect(x: 0, y: 0, width: w, height: h)]

        case .halvesVertical:
            let half = (w - gap) / 2
            return [
                CGRect(x: 0,          y: 0, width: half, height: h),
                CGRect(x: half + gap, y: 0, width: half, height: h)
            ]

        case .mainSideStack:
            let leftW  = (w - gap) * 0.6
            let rightW = w - leftW - gap
            let halfH  = (h - gap) / 2
            return [
                CGRect(x: 0,           y: 0,          width: leftW,  height: h),
                CGRect(x: leftW + gap, y: 0,          width: rightW, height: halfH),
                CGRect(x: leftW + gap, y: halfH + gap, width: rightW, height: halfH)
            ]

        case .quarters:
            let halfW = (w - gap) / 2
            let halfH = (h - gap) / 2
            return [
                CGRect(x: 0,          y: 0,           width: halfW, height: halfH),
                CGRect(x: halfW + gap, y: 0,           width: halfW, height: halfH),
                CGRect(x: 0,          y: halfH + gap, width: halfW, height: halfH),
                CGRect(x: halfW + gap, y: halfH + gap, width: halfW, height: halfH)
            ]
        }
    }

    // MARK: - Menu overlays (assignment mode)

    @ViewBuilder
    private func menuOverlays(for size: CGSize) -> some View {
        let gap: CGFloat = 2
        let rects = slotRects(in: size, gap: gap)
        ForEach(Array(rects.enumerated()), id: \.offset) { slot, rect in
            if let buildMenu = onSlotMenu {
                buildMenu(slot)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }
}

#Preview("Picker mode — all layouts") {
    HStack(spacing: 12) {
        ForEach(WorkspaceLayout.allCases, id: \.rawValue) { layout in
            VStack(spacing: 4) {
                WorkspaceLayoutThumbnail(layout: layout, size: CGSize(width: 60, height: 40))
                Text(layout.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .background(Color(red: 0.176, green: 0.176, blue: 0.176))
}
