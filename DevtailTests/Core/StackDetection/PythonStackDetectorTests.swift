//
//  PythonStackDetectorTests.swift
//  DevtailTests
//
//  Tests PythonStackDetector against fixture files written to a temp
//  directory. Same isolation pattern as NodeStackDetectorTests — every
//  test gets its own folder and cleans up afterwards.
//

import Testing
import Foundation
@testable import Devtail

@Suite("PythonStackDetector")
struct PythonStackDetectorTests {

    // MARK: - Fixture plumbing

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-python-detector-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func write(_ contents: String, named name: String, in folder: URL) throws {
        let target = folder.appendingPathComponent(name)
        try contents.data(using: .utf8)!.write(to: target)
    }

    private func cleanup(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - No signals → nil

    @Test("returns nil when there are no Python signals at all")
    func returnsNilWhenNoPythonSignals() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result == nil)
    }

    @Test("a lone unrelated file does not trigger detection")
    func unrelatedFileDoesNotTrigger() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("# readme", named: "README.md", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result == nil)
    }

    // MARK: - Django

    @Test("detects Django via manage.py")
    func detectsDjangoViaManagePy() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("#!/usr/bin/env python\n", named: "manage.py", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Django")
        #expect(result?.confidence == 95)
        #expect(result?.suggestedCommand == "python manage.py runserver")
    }

    @Test("detects Django via requirements.txt entry")
    func detectsDjangoViaRequirements() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("Django==4.2.0\npsycopg2==2.9\n", named: "requirements.txt", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Django")
        #expect(result?.suggestedCommand == "python manage.py runserver")
    }

    @Test("detects Django via pyproject.toml")
    func detectsDjangoViaPyproject() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("""
        [project]
        name = "site"
        dependencies = [
          "django>=4.2",
          "gunicorn"
        ]
        """, named: "pyproject.toml", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Django")
    }

    // MARK: - FastAPI

    @Test("detects FastAPI via requirements.txt")
    func detectsFastAPI() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("fastapi==0.110.0\nuvicorn[standard]==0.27.0\n", named: "requirements.txt", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "FastAPI")
        #expect(result?.confidence == 90)
        #expect(result?.suggestedCommand == "uvicorn main:app --reload")
    }

    @Test("detects FastAPI via pyproject.toml under poetry")
    func detectsFastAPIViaPoetry() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("""
        [tool.poetry.dependencies]
        python = "^3.11"
        fastapi = "^0.110"
        """, named: "pyproject.toml", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "FastAPI")
    }

    // MARK: - Flask

    @Test("detects Flask via requirements.txt")
    func detectsFlask() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("Flask==3.0.0\n", named: "requirements.txt", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Flask")
        #expect(result?.confidence == 90)
        #expect(result?.suggestedCommand == "flask run")
    }

    // MARK: - Generic Python fallback

    @Test("requirements.txt without known frameworks falls back to Python")
    func genericRequirementsFallback() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("requests==2.31.0\nnumpy==1.26.0\n", named: "requirements.txt", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Python")
        #expect(result?.confidence == 60)
        #expect(result?.suggestedCommand == nil)
    }

    @Test("pyproject.toml without known frameworks falls back to Python")
    func genericPyprojectFallback() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("""
        [project]
        name = "lib"
        dependencies = ["requests"]
        """, named: "pyproject.toml", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Python")
        #expect(result?.confidence == 60)
    }

    @Test("Pipfile alone counts as generic Python")
    func pipfileAloneIsPython() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("""
        [[source]]
        url = "https://pypi.org/simple"

        [packages]
        requests = "*"
        """, named: "Pipfile", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Python")
    }

    @Test("setup.py alone counts as generic Python")
    func setupPyAloneIsPython() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("from setuptools import setup\nsetup(name='x')\n", named: "setup.py", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Python")
    }

    // MARK: - Case-insensitive matching

    @Test("Django dependency match is case-insensitive")
    func djangoCaseInsensitive() async throws {
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("django==4.2\n", named: "requirements.txt", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Django")
    }

    // MARK: - Word-boundary matching

    @Test("dependency named django-something does not falsely match Django")
    func wordBoundaryFalsePositive() async throws {
        // A package called `djangorestframework-simplejwt-blacklist` should
        // NOT match the bare name `django` — only an exact `django` entry
        // (or an entry that starts with `django` followed by a version
        // operator) should count.
        //
        // Note: this is a regression guard. Substring matching would
        // happily match here and we'd label random JWT tooling as Django.
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("djangorestframework-simplejwt-blacklist==1.0\n", named: "requirements.txt", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        // Still Python (requirements.txt exists), but NOT Django.
        #expect(result?.label == "Python")
    }

    // MARK: - manage.py beats requirements.txt content

    @Test("manage.py wins even when requirements.txt mentions FastAPI")
    func managePyTrumpsRequirements() async throws {
        // Edge case: a Django project with a sidecar FastAPI service
        // in the same root. manage.py is the strongest signal that
        // this folder is intended as the Django project root.
        let folder = try makeFolder()
        defer { cleanup(folder) }
        try write("#!/usr/bin/env python\n", named: "manage.py", in: folder)
        try write("fastapi==0.110\n", named: "requirements.txt", in: folder)

        let result = try await PythonStackDetector().detect(folder: folder)

        #expect(result?.label == "Django")
    }
}
