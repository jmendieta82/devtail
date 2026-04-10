//
//  WorkspaceLayoutTests.swift
//  DevtailTests
//
//  Unit tests for WorkspaceLayout enum: slotCount, splitSequence (including
//  Quarters non-sequential assertion), displayName, and Project's layout
//  computed accessor fallback.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("WorkspaceLayout")
struct WorkspaceLayoutTests {

    // MARK: - slotCount

    @Test("full has slotCount 1")
    func fullSlotCount() {
        #expect(WorkspaceLayout.full.slotCount == 1)
    }

    @Test("halvesVertical has slotCount 2")
    func halvesVerticalSlotCount() {
        #expect(WorkspaceLayout.halvesVertical.slotCount == 2)
    }

    @Test("mainSideStack has slotCount 3")
    func mainSideStackSlotCount() {
        #expect(WorkspaceLayout.mainSideStack.slotCount == 3)
    }

    @Test("quarters has slotCount 4")
    func quartersSlotCount() {
        #expect(WorkspaceLayout.quarters.slotCount == 4)
    }

    // MARK: - displayName

    @Test("displayName smoke — all cases return a non-empty string")
    func displayNameNonEmpty() {
        for layout in WorkspaceLayout.allCases {
            #expect(!layout.displayName.isEmpty)
        }
    }

    @Test("displayName values are correct")
    func displayNameValues() {
        #expect(WorkspaceLayout.full.displayName == "Full")
        #expect(WorkspaceLayout.halvesVertical.displayName == "Halves")
        #expect(WorkspaceLayout.mainSideStack.displayName == "Main + Side")
        #expect(WorkspaceLayout.quarters.displayName == "Quarters")
    }

    // MARK: - splitSequence

    @Test("full splitSequence is empty")
    func fullSplitSequence() {
        #expect(WorkspaceLayout.full.splitSequence.isEmpty)
    }

    @Test("halvesVertical splitSequence has one step: slot0 → right → slot1")
    func halvesVerticalSplitSequence() {
        let seq = WorkspaceLayout.halvesVertical.splitSequence
        #expect(seq.count == 1)
        #expect(seq[0].sourceSlot == 0)
        #expect(seq[0].direction == .right)
        #expect(seq[0].newSlot == 1)
    }

    @Test("mainSideStack splitSequence has two steps: 0→right→1, then 1→down→2")
    func mainSideStackSplitSequence() {
        let seq = WorkspaceLayout.mainSideStack.splitSequence
        #expect(seq.count == 2)
        #expect(seq[0] == SplitStep(sourceSlot: 0, direction: .right, newSlot: 1))
        #expect(seq[1] == SplitStep(sourceSlot: 1, direction: .down,  newSlot: 2))
    }

    @Test("quarters splitSequence has three steps with non-sequential sources")
    func quartersSplitSequence() {
        let seq = WorkspaceLayout.quarters.splitSequence
        #expect(seq.count == 3)

        // Step 0: slot0 → right → slot1
        #expect(seq[0] == SplitStep(sourceSlot: 0, direction: .right, newSlot: 1))

        // Step 1: slot0 → down → slot2 (source is 0, NOT 1 — non-sequential)
        #expect(seq[1].sourceSlot == 0)
        #expect(seq[1].direction == .down)
        #expect(seq[1].newSlot == 2)

        // Step 2: slot1 → down → slot3 (source is 1, NOT 2)
        #expect(seq[2].sourceSlot == 1)
        #expect(seq[2].direction == .down)
        #expect(seq[2].newSlot == 3)
    }

    // MARK: - Raw value / Codable

    @Test("rawValue round-trips correctly for all cases")
    func rawValueRoundTrip() {
        for layout in WorkspaceLayout.allCases {
            #expect(WorkspaceLayout(rawValue: layout.rawValue) == layout)
        }
    }

    @Test("unknown rawValue returns nil")
    func unknownRawValue() {
        #expect(WorkspaceLayout(rawValue: "garbage") == nil)
        #expect(WorkspaceLayout(rawValue: "") == nil)
        #expect(WorkspaceLayout(rawValue: "FULL") == nil)
    }

    // MARK: - Project accessor fallback

    @Test("Project layout accessor defaults to .full on unknown rawValue")
    func projectLayoutFallback() {
        let project = Project(name: "P")
        project.layoutRaw = "corrupt_value"
        #expect(project.layout == .full)
    }

    @Test("Project layout accessor round-trips a known value")
    func projectLayoutRoundTrip() {
        let project = Project(name: "P")
        project.layout = .quarters
        #expect(project.layoutRaw == "quarters")
        #expect(project.layout == .quarters)
    }

    @Test("New Project defaults to .full layout")
    func newProjectDefaultLayout() {
        let project = Project(name: "P")
        #expect(project.layout == .full)
    }
}
