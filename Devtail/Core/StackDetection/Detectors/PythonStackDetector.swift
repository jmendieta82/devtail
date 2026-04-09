//
//  PythonStackDetector.swift
//  Devtail
//
//  Detects Python-based stacks. The detection lives in three layers:
//
//  1. `manage.py` in the root → Django, highest confidence (95). This
//     beats anything else in the folder because the file's only job is
//     to live next to a Django settings module.
//  2. Dependency files (`requirements.txt`, `pyproject.toml`, `Pipfile`)
//     are scanned for known framework names. Match → 90 confidence.
//  3. Any of the dependency files OR `setup.py` exists → fallback to
//     generic "Python" at confidence 60.
//
//  Dependency matching is intentionally simple: tokenize each line on
//  characters that cannot legally appear in a PyPI distribution name
//  (`=`, `<`, `>`, `[`, whitespace, quotes, commas, etc.) and look for
//  exact, case-insensitive name matches. This avoids false positives
//  from lookalikes such as `djangorestframework-simplejwt-blacklist`
//  matching `django`, while staying free of a real TOML/INI parser
//  dependency.
//

import Foundation

struct PythonStackDetector: StackDetector {
    let name = "python"

    /// Maps a normalized PyPI distribution name to the framework label
    /// and suggested startup command. Evaluated in order; the first
    /// match wins. The order matters because Django apps may pull in
    /// FastAPI helpers and we want the dominant framework to win.
    private static let frameworkSignatures: [(dependency: String, label: String, command: String)] = [
        ("django",  "Django",  "python manage.py runserver"),
        ("fastapi", "FastAPI", "uvicorn main:app --reload"),
        ("flask",   "Flask",   "flask run")
    ]

    /// Files that count as "this is a Python project" even when no
    /// framework can be identified. Order matters only for diagnostics.
    private static let pythonMarkerFiles: [String] = [
        "requirements.txt",
        "pyproject.toml",
        "Pipfile",
        "setup.py"
    ]

    func detect(folder: URL) async throws -> DetectedStack? {
        let fm = FileManager.default

        // Layer 1 — manage.py is the unambiguous Django marker.
        let managePy = folder.appendingPathComponent("manage.py")
        if fm.fileExists(atPath: managePy.path) {
            return DetectedStack(
                label: "Django",
                suggestedCommand: "python manage.py runserver",
                confidence: 95
            )
        }

        // Collect the dependency-bearing files that exist. We read all
        // of them so a project that splits deps across `requirements.txt`
        // and `pyproject.toml` still gets a single coherent answer.
        let dependencyFiles = ["requirements.txt", "pyproject.toml", "Pipfile"]
        var dependencyNames = Set<String>()
        var foundAnyDependencyFile = false

        for filename in dependencyFiles {
            let url = folder.appendingPathComponent(filename)
            guard fm.fileExists(atPath: url.path) else { continue }
            foundAnyDependencyFile = true
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                dependencyNames.formUnion(Self.extractDependencyTokens(from: contents))
            }
        }

        // Layer 2 — framework match against the merged token set.
        for signature in Self.frameworkSignatures {
            if dependencyNames.contains(signature.dependency) {
                return DetectedStack(
                    label: signature.label,
                    suggestedCommand: signature.command,
                    confidence: 90
                )
            }
        }

        // Layer 3 — generic Python fallback. Triggers when ANY marker
        // file is present, including `setup.py` (which has no parseable
        // dependency list we care to handle).
        let setupPy = folder.appendingPathComponent("setup.py")
        let hasSetupPy = fm.fileExists(atPath: setupPy.path)
        if foundAnyDependencyFile || hasSetupPy {
            return DetectedStack(label: "Python", suggestedCommand: nil, confidence: 60)
        }

        return nil
    }

    /// Extracts every plausible PyPI distribution name from a chunk of
    /// text. The approach is deliberately permissive about file format
    /// (works for `requirements.txt`, `pyproject.toml`, and `Pipfile`
    /// uniformly) and strict about token boundaries to avoid the
    /// substring false positives that bit us in the regression test.
    ///
    /// Algorithm:
    ///   1. Strip comments (everything after `#` on a line).
    ///   2. Split on every character that cannot appear in a PyPI name.
    ///      Legal characters per PEP 503: letters, digits, `-`, `_`, `.`.
    ///   3. Lowercase each token (PyPI names are case-insensitive).
    ///   4. Collect non-empty tokens into the result set.
    private static func extractDependencyTokens(from text: String) -> Set<String> {
        var result = Set<String>()

        // PEP 503 normalized name characters. Anything else is a
        // separator: whitespace, `=`, `<`, `>`, `[`, `]`, `"`, `'`,
        // `,`, `(`, `)`, `;`, `{`, `}`, etc.
        let nameCharacters = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        let separators = nameCharacters.inverted

        for rawLine in text.components(separatedBy: .newlines) {
            // Trim trailing comments — both `#` (Python/TOML/INI) style.
            let line: String
            if let hashIndex = rawLine.firstIndex(of: "#") {
                line = String(rawLine[..<hashIndex])
            } else {
                line = rawLine
            }

            for token in line.components(separatedBy: separators) {
                guard !token.isEmpty else { continue }
                // Lowercase for case-insensitive matching against the
                // signatures table.
                result.insert(token.lowercased())
            }
        }

        return result
    }
}
