//
//  LaunchTargetResolutionTests.swift
//  DevtailTests
//
//  Unit tests for the resolveLaunchTarget(project:settings:) pure function.
//  Verifies all four mapping cases: project beats settings unless project == .auto.
//

import Testing
import Foundation
@testable import Devtail

@MainActor
@Suite("resolveLaunchTarget — resolution helper")
struct LaunchTargetResolutionTests {

    private func makeProject(launchTarget: LaunchTarget = .auto) -> Project {
        let p = Project(name: "Test")
        p.launchTarget = launchTarget
        return p
    }

    private func makeSettings(defaultLaunchTarget: LaunchTarget) -> AppSettings {
        let defaults = UserDefaults(suiteName: "LaunchTargetResolutionTests-\(UUID().uuidString)")!
        defaults.set(defaultLaunchTarget.rawValue, forKey: "defaultLaunchTarget")
        return AppSettings(defaults: defaults)
    }

    // MARK: - .auto project defers to settings

    @Test("auto project + settings.defaultLaunchTarget=.auto → tabWithFallback")
    func autoProjectAutoSettings() {
        let project = makeProject(launchTarget: .auto)
        let settings = makeSettings(defaultLaunchTarget: .auto)
        #expect(resolveLaunchTarget(project: project, settings: settings) == .tabWithFallback)
    }

    @Test("auto project + settings.defaultLaunchTarget=.newWindow → windowOnly")
    func autoProjectNewWindowSettings() {
        let project = makeProject(launchTarget: .auto)
        let settings = makeSettings(defaultLaunchTarget: .newWindow)
        #expect(resolveLaunchTarget(project: project, settings: settings) == .windowOnly)
    }

    @Test("auto project + settings.defaultLaunchTarget=.newTab → tabWithFallback")
    func autoProjectNewTabSettings() {
        let project = makeProject(launchTarget: .auto)
        let settings = makeSettings(defaultLaunchTarget: .newTab)
        #expect(resolveLaunchTarget(project: project, settings: settings) == .tabWithFallback)
    }

    // MARK: - Project preference beats settings

    @Test("newTab project + any settings → tabWithFallback")
    func newTabProjectBeatsSettings() {
        let project = makeProject(launchTarget: .newTab)
        let settings = makeSettings(defaultLaunchTarget: .newWindow)
        #expect(resolveLaunchTarget(project: project, settings: settings) == .tabWithFallback)
    }

    @Test("newWindow project + any settings → windowOnly")
    func newWindowProjectBeatsSettings() {
        let project = makeProject(launchTarget: .newWindow)
        let settings = makeSettings(defaultLaunchTarget: .newTab)
        #expect(resolveLaunchTarget(project: project, settings: settings) == .windowOnly)
    }
}
