//
//  EnvFileDetectorTests.swift
//  DevtailTests
//
//  TDD for EnvFileDetector: which files become editable (the .env family).
//

import Testing
@testable import Devtail

struct EnvFileDetectorTests {
    @Test func plainDotEnvIsEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/.env") == true)
    }

    @Test func dotEnvLocalIsEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/.env.local") == true)
    }

    @Test func dotEnvDevelopmentIsEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/.env.development") == true)
    }

    @Test func uppercaseEnvIsEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/.ENV") == true)
    }

    @Test func mixedCaseEnvLocalIsEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/.Env.Local") == true)
    }

    @Test func regularSwiftFileIsNotEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/main.swift") == false)
    }

    @Test func fileContainingEnvButNotPrefixedIsNotEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/whatever.env") == false)
    }

    @Test func fileNamedEnvironmentIsNotEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/environment.ts") == false)
    }

    @Test func dotEnvironmentIsNotEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/.environment") == false)
    }

    @Test func dotEnvIsEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/.env") == true)
    }

    @Test func dotEnvDotLocalIsEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/.env.local") == true)
    }

    @Test func uppercaseDotEnvDotLocalIsEditable() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/project/.ENV.LOCAL") == true)
    }

    @Test func onlyLastPathComponentMatters() {
        #expect(EnvFileDetector.isEnvFile(path: "/tmp/.env/nested/main.swift") == false)
    }

    @Test func bareFilenameWithoutDirectoryWorks() {
        #expect(EnvFileDetector.isEnvFile(path: ".env.production") == true)
    }
}
