//
//  WorkspaceLayout.swift
//  Devtail
//
//  Defines the fixed set of workspace layouts, the split topology that
//  produces each layout in Ghostty, and the supporting value types.
//
//  SplitDirection and SplitStep are defined here (not in separate files)
//  because they are tightly coupled to WorkspaceLayout and have no
//  independent existence — a SplitStep only makes sense as part of a
//  layout's splitSequence.
//

import Foundation

// MARK: - SplitDirection

enum SplitDirection: String, Sendable {
    case right
    case down
}

// MARK: - SplitStep

struct SplitStep: Sendable, Equatable {
    let sourceSlot: Int
    let direction: SplitDirection
    let newSlot: Int
}

// MARK: - WorkspaceLayout

enum WorkspaceLayout: String, CaseIterable, Codable, Sendable {
    case full           = "full"
    case halvesVertical = "halvesVertical"
    case mainSideStack  = "mainSideStack"
    case quarters       = "quarters"

    var slotCount: Int {
        switch self {
        case .full:           1
        case .halvesVertical: 2
        case .mainSideStack:  3
        case .quarters:       4
        }
    }

    var displayName: String {
        switch self {
        case .full:           "Full"
        case .halvesVertical: "Halves"
        case .mainSideStack:  "Main + Side"
        case .quarters:       "Quarters"
        }
    }

    /// The ordered sequence of split operations that produce this layout
    /// in Ghostty. Each step splits from `sourceSlot` (an already-open
    /// terminal variable `term<N>`) in the given direction, binding the
    /// new terminal to `newSlot` (`term<newSlot>`).
    ///
    /// Quarters critical property: step[1] splits from slot 0 (NOT 1),
    /// and step[2] splits from slot 1 (NOT 2). This produces a true 2×2
    /// grid rather than a sequential 1×4 chain.
    var splitSequence: [SplitStep] {
        switch self {
        case .full:
            []
        case .halvesVertical:
            [
                SplitStep(sourceSlot: 0, direction: .right, newSlot: 1)
            ]
        case .mainSideStack:
            [
                SplitStep(sourceSlot: 0, direction: .right, newSlot: 1),
                SplitStep(sourceSlot: 1, direction: .down,  newSlot: 2)
            ]
        case .quarters:
            [
                SplitStep(sourceSlot: 0, direction: .right, newSlot: 1),
                SplitStep(sourceSlot: 0, direction: .down,  newSlot: 2),
                SplitStep(sourceSlot: 1, direction: .down,  newSlot: 3)
            ]
        }
    }
}
