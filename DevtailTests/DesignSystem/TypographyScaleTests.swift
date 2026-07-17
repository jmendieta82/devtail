//
//  TypographyScaleTests.swift
//  DevtailTests
//
//  Pins the point-size math backing DevtailTokens.Typography so the
//  baseSize-relative scale never silently drifts from the legacy fixed
//  sizes it replaced (all values below are the pre-scaling constants at
//  base 12).
//

import Testing
import SwiftUI
@testable import Devtail

@Suite("Typography scale", .serialized)
struct TypographyScaleTests {

    @Test("pointSize(for:) matches legacy fixed sizes at baseSize 12")
    func pointSizeMatchesLegacySizesAtBaseTwelve() {
        DevtailTokens.Typography.baseSize = 12

        #expect(DevtailTokens.Typography.pointSize(for: .projectTitle) == 18)
        #expect(DevtailTokens.Typography.pointSize(for: .titleLarge) == 18)
        #expect(DevtailTokens.Typography.pointSize(for: .titleMedium) == 14)
        #expect(DevtailTokens.Typography.pointSize(for: .headline) == 13)
        #expect(DevtailTokens.Typography.pointSize(for: .body) == 14)
        #expect(DevtailTokens.Typography.pointSize(for: .bodySemibold) == 14)
        #expect(DevtailTokens.Typography.pointSize(for: .bodyDefault) == 13)
        #expect(DevtailTokens.Typography.pointSize(for: .bodySmall) == 12)
        #expect(DevtailTokens.Typography.pointSize(for: .caption) == 12)
        #expect(DevtailTokens.Typography.pointSize(for: .captionSmall) == 10)
        #expect(DevtailTokens.Typography.pointSize(for: .micro) == 9)
        #expect(DevtailTokens.Typography.pointSize(for: .mono) == 13)
        #expect(DevtailTokens.Typography.pointSize(for: .monoSmall) == 11)
        #expect(DevtailTokens.Typography.pointSize(for: .monoBold) == 13)
        #expect(DevtailTokens.Typography.pointSize(for: .monoDefault) == 12)
        #expect(DevtailTokens.Typography.pointSize(for: .statValue) == 20)
        #expect(DevtailTokens.Typography.pointSize(for: .statValueSmall) == 14)
        #expect(DevtailTokens.Typography.pointSize(for: .statLabel) == 11)
        #expect(DevtailTokens.Typography.pointSize(for: .statSub) == 11)

        DevtailTokens.Typography.baseSize = 12
    }

    @Test("pointSize(for:) scales relative to baseSize")
    func pointSizeScalesWithBaseSize() {
        DevtailTokens.Typography.baseSize = 16

        #expect(DevtailTokens.Typography.pointSize(for: .caption) == 16)
        #expect(DevtailTokens.Typography.pointSize(for: .captionSmall) == 14)
        #expect(DevtailTokens.Typography.pointSize(for: .body) == 18)
        #expect(DevtailTokens.Typography.pointSize(for: .titleLarge) == 22)

        DevtailTokens.Typography.baseSize = 12
    }

    @Test("Font tokens reflect the current baseSize")
    func fontTokensReflectCurrentBaseSize() {
        DevtailTokens.Typography.baseSize = 12
        #expect(DevtailTokens.Typography.caption == .system(size: 12))

        DevtailTokens.Typography.baseSize = 14
        #expect(DevtailTokens.Typography.caption == .system(size: 14))

        DevtailTokens.Typography.baseSize = 12
    }
}
