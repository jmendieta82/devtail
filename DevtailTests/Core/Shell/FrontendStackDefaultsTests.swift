//
//  FrontendStackDefaultsTests.swift
//  DevtailTests
//
//  Tests for FrontendStackDefaults — pure functions, no mocking needed.
//

import Testing
import Foundation
@testable import Devtail

@Suite("FrontendStackDefaults")
struct FrontendStackDefaultsTests {

    // MARK: - isFrontend(label:)

    @Test("isFrontend returns true for React")
    func isFrontendReact() {
        #expect(FrontendStackDefaults.isFrontend(label: "React") == true)
    }

    @Test("isFrontend returns true for Angular")
    func isFrontendAngular() {
        #expect(FrontendStackDefaults.isFrontend(label: "Angular") == true)
    }

    @Test("isFrontend returns true for Next.js")
    func isFrontendNextJs() {
        #expect(FrontendStackDefaults.isFrontend(label: "Next.js") == true)
    }

    @Test("isFrontend returns true for Vue")
    func isFrontendVue() {
        #expect(FrontendStackDefaults.isFrontend(label: "Vue") == true)
    }

    @Test("isFrontend returns false for nil")
    func isFrontendNil() {
        #expect(FrontendStackDefaults.isFrontend(label: nil) == false)
    }

    @Test("isFrontend returns false for empty string")
    func isFrontendEmpty() {
        #expect(FrontendStackDefaults.isFrontend(label: "") == false)
    }

    @Test("isFrontend returns false for Django")
    func isFrontendDjango() {
        #expect(FrontendStackDefaults.isFrontend(label: "Django") == false)
    }

    @Test("isFrontend returns false for Go")
    func isFrontendGo() {
        #expect(FrontendStackDefaults.isFrontend(label: "Go") == false)
    }

    @Test("isFrontend returns false for Nest")
    func isFrontendNest() {
        #expect(FrontendStackDefaults.isFrontend(label: "Nest") == false)
    }

    // MARK: - defaultURL(forLabel:)

    @Test("defaultURL returns Angular port for Angular")
    func defaultURLAngular() {
        #expect(FrontendStackDefaults.defaultURL(forLabel: "Angular") == "http://localhost:4200")
    }

    @Test("defaultURL returns React port for React")
    func defaultURLReact() {
        #expect(FrontendStackDefaults.defaultURL(forLabel: "React") == "http://localhost:3000")
    }

    @Test("defaultURL returns Next.js port for Next.js")
    func defaultURLNextJs() {
        #expect(FrontendStackDefaults.defaultURL(forLabel: "Next.js") == "http://localhost:3000")
    }

    @Test("defaultURL returns Vue port for Vue")
    func defaultURLVue() {
        #expect(FrontendStackDefaults.defaultURL(forLabel: "Vue") == "http://localhost:5173")
    }

    @Test("defaultURL returns genericDefaultURL for nil")
    func defaultURLNil() {
        #expect(FrontendStackDefaults.defaultURL(forLabel: nil) == FrontendStackDefaults.genericDefaultURL)
    }

    @Test("defaultURL returns genericDefaultURL for unknown label")
    func defaultURLUnknown() {
        #expect(FrontendStackDefaults.defaultURL(forLabel: "UnknownThing") == FrontendStackDefaults.genericDefaultURL)
    }

    @Test("defaultURL returns genericDefaultURL for Django")
    func defaultURLDjango() {
        #expect(FrontendStackDefaults.defaultURL(forLabel: "Django") == FrontendStackDefaults.genericDefaultURL)
    }

    @Test("genericDefaultURL is http://localhost:3000")
    func genericDefaultURLValue() {
        #expect(FrontendStackDefaults.genericDefaultURL == "http://localhost:3000")
    }
}
