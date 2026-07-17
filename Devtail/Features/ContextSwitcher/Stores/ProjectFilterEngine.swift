//
//  ProjectFilterEngine.swift
//  Devtail
//
//  Pure substring filter for the project list. Lives outside the views
//  so the search rules can be tested in isolation and reused wherever
//  project filtering is needed.
//
//  Match rules (locked in tests, do not change without updating them):
//    - Empty / whitespace-only query → returns the input unchanged.
//    - Otherwise the query is trimmed, lowercased, and tested as a
//      substring against a per-project "haystack" built from the
//      `name` and `directoryPath` fields.
//    - Input order is preserved for matching projects (no ranking).
//
//  Note: environment is no longer searched. It moved from Project to
//  WorkspacePane in a later refactor, and pane-level filtering is a
//  separate decision we've intentionally deferred.
//
//  Concurrency: marked Sendable. The engine has no state and never
//  touches @MainActor data — `Project` instances flow in from the
//  caller, which is responsible for any actor isolation around them.
//

import Foundation

struct ProjectFilterEngine: Sendable {

    init() {}

    /// Returns the subset of `projects` whose searchable text contains
    /// `query` (case-insensitive substring). When `query` is empty or
    /// whitespace-only, the full input is returned in original order.
    ///
    /// The "searchable text" of a project is the lowercased
    /// concatenation of `name`, `directoryPath`, and the environment
    /// label. We deliberately stop at three fields — adding stacks,
    /// notes, or quick links would creep the scope and conflict with
    /// the locked decision in the search feature spec.
    func filter(projects: [Project], query: String) -> [Project] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return projects }

        let needle = trimmed.lowercased()
        return projects.filter { project in
            Self.haystack(for: project).contains(needle)
        }
    }

    /// Builds the searchable text for a single project. Lowercased once
    /// per project per filter call — the cost is negligible for the
    /// list sizes Devtail targets (tens to low hundreds of projects)
    /// and avoids cache-invalidation headaches.
    private static func haystack(for project: Project) -> String {
        // Joined with a space so substrings can't accidentally bridge
        // two adjacent fields (e.g. a project named "abc" with path
        // "def" should NOT match the query "cdef").
        [
            project.name,
            project.directoryPath
        ]
        .joined(separator: " ")
        .lowercased()
    }
}
