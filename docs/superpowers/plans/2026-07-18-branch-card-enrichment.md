# Branch Card Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich the workspace Branch card with an expandable local-branch list (current branch highlighted) and the last commit of HEAD (subject + relative time).

**Architecture:** `GitStatusReader` already runs `git branch --format=%(refname:short)` but collapses the output to a count; we keep the names instead and add one `git log -1` invocation, both behind pure static parsers (the TDD targets). The card UI reuses the `DisclosureGroup` pattern from `claudeCategoryRow` in the same file.

**Tech Stack:** Swift 5 mode, SwiftUI, Swift Testing (`@Suite`/`@Test`/`#expect`), xcodebuild.

## Global Constraints

- Swift 5 language mode, MainActor default isolation, macOS 26.0 Tahoe minimum (project `CLAUDE.md`).
- Conventional Commits, NEVER any Co-Authored-By/AI attribution.
- No new SPM dependencies.
- Read-only feature: no git write commands of any kind (design doc: option C rejected).
- Full suite command: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS'` run from `/Volumes/Datos/Frelancer/DEVTAIL/Devtail`.

---

### Task 1: Parsers — `parseBranchList` replaces `parseBranchCount`, new `parseLastCommit`

**Files:**
- Modify: `Devtail/Core/GitDetection/GitStatusReader.swift` (parsers section, lines ~159-195, and `status(in:)` line ~70)
- Test: `DevtailTests/Core/GitDetection/GitStatusReaderTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `static func parseBranchList(_ output: String) -> [String]` and `static func parseLastCommit(_ output: String) -> (subject: String, date: Date)?` on `GitStatusReader`. `parseBranchCount` is deleted. `GitStatus` shape is unchanged in this task (`status(in:)` uses `parseBranchList(...).count`).

- [ ] **Step 1: Write the failing tests**

In `GitStatusReaderTests.swift`, replace the whole `// MARK: - parseBranchCount` section (three tests) with:

```swift
    // MARK: - parseBranchList

    @Test("parseBranchList returns one branch name per line, in order")
    func parseBranchListMultiple() {
        #expect(GitStatusReader.parseBranchList("main\ndev\n") == ["main", "dev"])
    }

    @Test("parseBranchList returns empty for empty output")
    func parseBranchListEmpty() {
        #expect(GitStatusReader.parseBranchList("") == [])
    }

    @Test("parseBranchList ignores blank lines and trims whitespace")
    func parseBranchListIgnoresBlankLines() {
        #expect(GitStatusReader.parseBranchList("main\n\n  dev \n") == ["main", "dev"])
    }

    // MARK: - parseLastCommit

    @Test("parseLastCommit parses subject and unix timestamp")
    func parseLastCommitValid() {
        let result = GitStatusReader.parseLastCommit("fix: teardown race\t1752854400\n")
        #expect(result?.subject == "fix: teardown race")
        #expect(result?.date == Date(timeIntervalSince1970: 1_752_854_400))
    }

    @Test("parseLastCommit keeps tabs inside the subject (splits on the last tab)")
    func parseLastCommitSubjectWithTab() {
        let result = GitStatusReader.parseLastCommit("subject\twith tab\t1752854400")
        #expect(result?.subject == "subject\twith tab")
        #expect(result?.date == Date(timeIntervalSince1970: 1_752_854_400))
    }

    @Test("parseLastCommit returns nil for empty output")
    func parseLastCommitEmpty() {
        #expect(GitStatusReader.parseLastCommit("") == nil)
    }

    @Test("parseLastCommit returns nil when the tab separator is missing")
    func parseLastCommitMissingTab() {
        #expect(GitStatusReader.parseLastCommit("just a subject") == nil)
    }

    @Test("parseLastCommit returns nil for a non-numeric timestamp")
    func parseLastCommitBadTimestamp() {
        #expect(GitStatusReader.parseLastCommit("subject\tnot-a-number") == nil)
    }
```

- [ ] **Step 2: Run the suite to verify it fails to compile**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -20`
Expected: compile FAILURE — `parseBranchList` / `parseLastCommit` not found (`parseBranchCount` references also gone from tests).

- [ ] **Step 3: Implement the parsers**

In `GitStatusReader.swift`, replace `parseBranchCount` (lines ~187-195) with:

```swift
    /// Parses `git branch --format=%(refname:short)` output: one local
    /// branch name per non-blank line, order preserved.
    static func parseBranchList(_ output: String) -> [String] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Parses `git log -1 --format=%s%x09%ct` output: commit subject, a
    /// tab, and the unix committer timestamp. Splits on the LAST tab so a
    /// subject containing tabs stays intact. Returns nil for any malformed
    /// shape (no tab, empty subject, non-numeric timestamp).
    static func parseLastCommit(_ output: String) -> (subject: String, date: Date)? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let tabIndex = trimmed.lastIndex(of: "\t") else { return nil }
        let subject = String(trimmed[..<tabIndex]).trimmingCharacters(in: .whitespaces)
        let timestampText = String(trimmed[trimmed.index(after: tabIndex)...])
        guard !subject.isEmpty, let timestamp = TimeInterval(timestampText) else { return nil }
        return (subject: subject, date: Date(timeIntervalSince1970: timestamp))
    }
```

In `status(in:)`, replace the branch-count lines (~69-70):

```swift
        let branchListOutput = await Self.run(["branch", "--format=%(refname:short)"], in: root) ?? ""
        let localBranchCount = Self.parseBranchList(branchListOutput).count
```

Also update the file-header comment (lines ~17-18): `parseBranchCount` → `parseBranchList`, and mention `parseLastCommit`.

- [ ] **Step 4: Run the suite to verify it passes**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` (suite was 550 tests; now 550 − 3 + 8 = 555).

- [ ] **Step 5: Commit**

```bash
git add Devtail/Core/GitDetection/GitStatusReader.swift DevtailTests/Core/GitDetection/GitStatusReaderTests.swift
git commit -m "feat(git): parse branch names and last commit from git output"
```

---

### Task 2: `GitStatus` shape — `localBranches` + last commit fields wired through

**Files:**
- Modify: `Devtail/Core/GitDetection/GitStatusReader.swift` (`GitStatus` struct lines ~27-37, `status(in:)` lines ~62-92)
- Modify: `Devtail/Features/Workspace/Views/Components/WorkspaceDashboardColumn.swift:107` (count read)
- Modify: `DevtailTests/Features/Workspace/WorkspaceSessionGitStatusTests.swift:31` (fixture)

**Interfaces:**
- Consumes: `parseBranchList` / `parseLastCommit` from Task 1.
- Produces: the final `GitStatus` shape every later task and view relies on:

```swift
struct GitStatus: Equatable, Sendable {
    let branch: String
    let localBranches: [String]
    let isDirty: Bool
    let changedFileCount: Int
    let ahead: Int?
    let behind: Int?
    let lastCommitSubject: String?
    let lastCommitDate: Date?
}
```

`localBranchCount` no longer exists — consumers use `localBranches.count`.

- [ ] **Step 1: Update the test fixture to the new shape (failing compile is the "failing test")**

In `WorkspaceSessionGitStatusTests.swift` line 31, replace the fixture:

```swift
        GitStatus(
            branch: "main",
            localBranches: ["main", "dev"],
            isDirty: true,
            changedFileCount: 3,
            ahead: 1,
            behind: 0,
            lastCommitSubject: "feat: something",
            lastCommitDate: Date(timeIntervalSince1970: 1_752_854_400)
        )
```

- [ ] **Step 2: Run the suite to verify it fails to compile**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -20`
Expected: compile FAILURE — `GitStatus` has no `localBranches` / `lastCommitSubject` members.

- [ ] **Step 3: Change the struct and wire the reader**

In `GitStatusReader.swift`, replace the `GitStatus` struct (lines ~27-37) with the shape shown in **Interfaces** above, updating its doc comment to: optional fields (`ahead`/`behind`, `lastCommitSubject`/`lastCommitDate`) are nil when there is no upstream / no readable HEAD commit.

In `status(in:)`, replace the branch-count line from Task 1 and the return:

```swift
        let branchListOutput = await Self.run(["branch", "--format=%(refname:short)"], in: root) ?? ""
        let localBranches = Self.parseBranchList(branchListOutput)
```

after the ahead/behind block, add:

```swift
        var lastCommitSubject: String?
        var lastCommitDate: Date?
        if let logOutput = await Self.run(["log", "-1", "--format=%s%x09%ct"], in: root),
           let parsed = Self.parseLastCommit(logOutput) {
            lastCommitSubject = parsed.subject
            lastCommitDate = parsed.date
        }

        return GitStatus(
            branch: branch,
            localBranches: localBranches,
            isDirty: isDirty,
            changedFileCount: changedFileCount,
            ahead: ahead,
            behind: behind,
            lastCommitSubject: lastCommitSubject,
            lastCommitDate: lastCommitDate
        )
```

In `WorkspaceDashboardColumn.swift` line 107, change:

```swift
            Text("\(status.localBranches.count) branches")
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`, same test count as Task 1 (555).

- [ ] **Step 5: Commit**

```bash
git add Devtail/Core/GitDetection/GitStatusReader.swift Devtail/Features/Workspace/Views/Components/WorkspaceDashboardColumn.swift DevtailTests/Features/Workspace/WorkspaceSessionGitStatusTests.swift
git commit -m "feat(git): carry branch names and last commit in GitStatus"
```

---

### Task 3: Branch card UI — expandable branch list + last commit row

**Files:**
- Modify: `Devtail/Features/Workspace/Views/Components/WorkspaceDashboardColumn.swift` (`gitStatusDetails`, lines ~102-121)

**Interfaces:**
- Consumes: `GitStatus.localBranches`, `.branch`, `.lastCommitSubject`, `.lastCommitDate` from Task 2; existing `DevtailTokens` (`Typography.caption`, `Typography.captionSmall`, `Colors.textSecondary`, `Colors.accentPrimary`, `Spacing.gapTiny`) and the `DisclosureGroup` styling conventions from `claudeCategoryRow` in the same file.
- Produces: view-only change; no new public API.

No unit test — SwiftUI view body, verified at Javier's visual checkpoint (project convention; same as every prior card).

- [ ] **Step 1: Rewrite `gitStatusDetails`**

Replace the `gitStatusDetails` function (lines ~102-121) with:

```swift
    /// Enriched git details shown once `gitStatus` has loaded: expandable
    /// local branch list (current branch highlighted), dirty/clean state,
    /// last commit (subject + relative time, hidden when HEAD is unreadable),
    /// and ahead/behind vs. upstream (hidden when there is no upstream).
    private func gitStatusDetails(_ status: GitStatus) -> some View {
        VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
            branchListRow(status)

            Text(status.isDirty ? "\(status.changedFileCount) uncommitted" : "Clean")
                .font(DevtailTokens.Typography.captionSmall)
                .foregroundStyle(status.isDirty ? DevtailTokens.Colors.trafficYellow : DevtailTokens.Colors.trafficGreen)

            if let subject = status.lastCommitSubject, let date = status.lastCommitDate {
                Text("\(subject) \u{00B7} \(Self.relativeFormatter.localizedString(for: date, relativeTo: Date()))")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .help(subject)
            }

            if let ahead = status.ahead, let behind = status.behind {
                Text("\u{2191}\(ahead) \u{2193}\(behind)")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
            }
        }
    }

    /// "N branches" row: plain text when the list is empty (nothing to
    /// expand into), otherwise a DisclosureGroup listing every local branch
    /// with the current one highlighted — same shape as `claudeCategoryRow`.
    private func branchListRow(_ status: GitStatus) -> some View {
        Group {
            if status.localBranches.isEmpty {
                Text("0 branches")
                    .font(DevtailTokens.Typography.captionSmall)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
            } else {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapTiny) {
                        ForEach(status.localBranches, id: \.self) { name in
                            Label(name, systemImage: name == status.branch ? "checkmark" : "arrow.triangle.branch")
                                .font(DevtailTokens.Typography.captionSmall)
                                .foregroundStyle(name == status.branch
                                    ? DevtailTokens.Colors.accentPrimary
                                    : DevtailTokens.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, DevtailTokens.Spacing.gapTiny)
                } label: {
                    Text("\(status.localBranches.count) branches")
                        .font(DevtailTokens.Typography.captionSmall)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                }
            }
        }
    }

    /// Shared formatter for the last-commit relative timestamp ("2h ago").
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
```

Note: `RelativeDateTimeFormatter` comes from Foundation, already imported transitively via SwiftUI in this file — add `import Foundation` only if the compiler asks for it.

- [ ] **Step 2: Run the suite to verify everything still passes**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` (555 tests).

- [ ] **Step 3: Commit**

```bash
git add Devtail/Features/Workspace/Views/Components/WorkspaceDashboardColumn.swift
git commit -m "feat(workspace): expandable branch list and last commit in Branch card"
```
