# Send Task To Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Send to agent` action to the task card menu that pastes the task title into a chosen agent tab's prompt without submitting it.

**Architecture:** Three layers. `TerminalSession` gains a `sendBracketedText(_:)` method so the existing bracketed-paste wrap in `AgentTerminalView` is reachable through the protocol. `WorkspaceSession` gains `sendTask(title:toAgent:)` which writes to the targeted agent's session and selects its tab. `TaskBoardTabView`'s existing `...` menu gains the entry, collapsing between a flat button and a submenu based on how many live agents exist.

**Tech Stack:** Swift 5 language mode, SwiftUI, SwiftTerm, Swift Testing (`@Test` / `#expect`), Xcode 26.4.

## Global Constraints

- Swift 5 language mode (`SWIFT_VERSION = 5.0`), MainActor default isolation.
- macOS 26.0 Tahoe minimum — no newer APIs.
- Test framework is Swift Testing (`import Testing`, `@Test`, `#expect`), NOT XCTest.
- Never run builds proactively; the user runs them. Tests are run with the command in each task.
- No comments explaining obvious Swift syntax — the user is senior.
- Conventional Commits, no AI attribution in commit messages.
- Prompt prefix is exactly `Tarea del board: ` (Spanish, matches the user's board language).

---

### Task 1: `sendBracketedText` on the terminal session protocol

Widens `AgentTerminalView.sendBracketedPath` to arbitrary text and exposes it through `TerminalSession`, so callers outside the view can paste into the agent prompt.

**Files:**
- Modify: `Devtail/Features/Workspace/Views/AgentTerminalView.swift:82`
- Modify: `Devtail/Features/Workspace/Services/TerminalEngine.swift:47`
- Modify: `Devtail/Features/Workspace/Services/SwiftTermEngine.swift:88`
- Modify: `DevtailTests/Features/Workspace/MockTerminalEngine.swift:24`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `TerminalSession.sendBracketedText(_ text: String)`. `MockTerminalSession.bracketedWrites: [String]` records calls for later tasks' assertions.

- [ ] **Step 1: Add the protocol method and the mock recorder**

In `TerminalEngine.swift`, add to the `TerminalSession` protocol right after `writeToStdin`:

```swift
    /// Paste `text` as if the user pasted it: bracketed-paste wrapped when the
    /// running program enabled mode 2004. Unlike `writeToStdin`, this is what
    /// a TUI like Claude Code needs to receive text as prompt input rather
    /// than as keystrokes.
    func sendBracketedText(_ text: String)
```

In `MockTerminalEngine.swift`, add the recorder alongside `written`:

```swift
    private(set) var bracketedWrites: [String] = []
```

and the method next to `writeToStdin`:

```swift
    func sendBracketedText(_ text: String) { bracketedWrites.append(text) }
```

- [ ] **Step 2: Run the suite to verify it fails to build**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -30`
Expected: FAIL — `SwiftTermEngine.Session` does not conform to `TerminalSession` (missing `sendBracketedText`).

- [ ] **Step 3: Rename the view method and implement the engine forward**

In `AgentTerminalView.swift`, change the doc comment and signature at line 76-87 from path-specific to text-generic, and make it non-private:

```swift
    /// Hand-rolled bracketed-paste wrap shared by paste, drop, and the task
    /// board's "send to agent": SwiftTerm's
    /// insertText(_:replacementRange:isPaste:) overload is internal to the
    /// SwiftTerm module, so we replicate its paste path (MacTerminalView
    /// non-kitty branch) with public API only. If the running program never
    /// enabled mode 2004, the text is sent unwrapped instead of leaking
    /// escape sequences.
    func sendBracketedText(_ text: String) {
        let bracketed = getTerminal().bracketedPasteMode
        if bracketed { send(data: EscapeSequences.bracketedPasteStart[0...]) }
        send(txt: text)
        if bracketed { send(data: EscapeSequences.bracketedPasteEnd[0...]) }
    }
```

Update its three call sites in the same file — lines 36, 62, and 71 — from `sendBracketedPath(...)` to `sendBracketedText(...)`. The arguments (`url.path`) stay exactly as they are.

In `SwiftTermEngine.swift`, add after `writeToStdin` (line 90):

```swift
    func sendBracketedText(_ text: String) {
        if let agentView = terminalView as? AgentTerminalView {
            agentView.sendBracketedText(text)
        } else {
            terminalView.send(txt: text)
        }
    }
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -30`
Expected: PASS, same test count as before this task (no new tests yet — this step only restores the build).

- [ ] **Step 5: Commit**

```bash
git add Devtail/Features/Workspace/Views/AgentTerminalView.swift \
        Devtail/Features/Workspace/Services/TerminalEngine.swift \
        Devtail/Features/Workspace/Services/SwiftTermEngine.swift \
        DevtailTests/Features/Workspace/MockTerminalEngine.swift
git commit -m "refactor(workspace): expose bracketed paste through TerminalSession"
```

---

### Task 2: `sendTask(title:toAgent:)` on the workspace session

The send action itself: format the prompt, write it to the targeted agent, select that tab.

**Files:**
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift` (in `WorkspaceSession`, after `closeSettings()` at line 226)
- Create: `DevtailTests/Features/Workspace/WorkspaceSessionSendTaskTests.swift`

**Interfaces:**
- Consumes: `TerminalSession.sendBracketedText(_:)` and `MockTerminalSession.bracketedWrites` from Task 1.
- Produces: `WorkspaceSession.sendTask(title: String, toAgent agentId: UUID)` and `WorkspaceSession.liveAgents: [AgentInstance]`, both used by Task 3.

- [ ] **Step 1: Write the failing tests**

Create `DevtailTests/Features/Workspace/WorkspaceSessionSendTaskTests.swift`:

```swift
//
//  WorkspaceSessionSendTaskTests.swift
//  DevtailTests
//
//  TDD for sending a task board card into an agent tab: the text reaches the
//  targeted agent only, carries the board prefix, selects that tab, and skips
//  dead agents.
//

import Foundation
import SwiftData
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionSendTaskTests {
    private func makeSUT(agentCount: Int = 1) -> (WorkspaceSession, [MockTerminalSession]) {
        var mocks: [MockTerminalSession] = []
        let first = MockTerminalSession()
        mocks.append(first)
        let session = WorkspaceSession(
            projectId: UUID(), projectName: "Demo",
            root: URL(fileURLWithPath: "/tmp/demo", isDirectory: true),
            supervisor: ProcessSupervisor(engine: MockTerminalEngine(), browserLauncher: MockBrowserLauncher()),
            agent: AgentInstance(title: "agent", session: first)
        )
        for index in 1..<max(agentCount, 1) {
            let mock = MockTerminalSession()
            mocks.append(mock)
            session.agents.append(AgentInstance(title: "agent \(index + 1)", session: mock))
        }
        return (session, mocks)
    }

    @Test func sendsPrefixedTitleToTargetedAgent() {
        let (session, mocks) = makeSUT(agentCount: 2)

        session.sendTask(title: "Arreglar el PDF", toAgent: session.agents[1].id)

        #expect(mocks[1].bracketedWrites == ["Tarea del board: Arreglar el PDF"])
        #expect(mocks[0].bracketedWrites.isEmpty)
    }

    @Test func selectsTargetedAgentTab() {
        let (session, _) = makeSUT(agentCount: 2)
        let target = session.agents[1].id

        session.sendTask(title: "Arreglar el PDF", toAgent: target)

        #expect(session.selectedTab == .agent(target))
    }

    @Test func unknownAgentIdIsNoOp() {
        let (session, mocks) = makeSUT(agentCount: 2)
        let original = session.selectedTab

        session.sendTask(title: "Arreglar el PDF", toAgent: UUID())

        #expect(mocks.allSatisfy { $0.bracketedWrites.isEmpty })
        #expect(session.selectedTab == original)
    }

    @Test func liveAgentsExcludesExitedOnes() {
        let (session, _) = makeSUT(agentCount: 3)
        session.agents[1].exited = true

        #expect(session.liveAgents.map(\.title) == ["agent", "agent 3"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -only-testing:DevtailTests/WorkspaceSessionSendTaskTests 2>&1 | tail -30`
Expected: FAIL — `value of type 'WorkspaceSession' has no member 'sendTask'` and `no member 'liveAgents'`.

- [ ] **Step 3: Implement on `WorkspaceSession`**

In `WorkspaceSessionsHolder.swift`, insert after `closeSettings()` (line 226):

```swift
    /// Agents whose PTY child is still alive — the only valid destinations
    /// for `sendTask`. Writing to an exited agent is swallowed silently by
    /// the dead PTY, which reads as success; the task board filters them out
    /// of its menu instead.
    var liveAgents: [AgentInstance] {
        agents.filter { !$0.exited }
    }

    /// Paste a task board card's title into `agentId`'s prompt and switch to
    /// that tab. The text is pasted, NOT submitted — the user edits and
    /// presses Enter, same contract as the agent tab's image drag & drop.
    /// Unknown ids are a no-op.
    func sendTask(title: String, toAgent agentId: UUID) {
        guard let instance = agentInstance(with: agentId) else { return }
        instance.session.sendBracketedText("Tarea del board: \(title)")
        selectedTab = .agent(agentId)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -only-testing:DevtailTests/WorkspaceSessionSendTaskTests 2>&1 | tail -30`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift \
        DevtailTests/Features/Workspace/WorkspaceSessionSendTaskTests.swift
git commit -m "feat(workspace): send a task board card into an agent prompt"
```

---

### Task 3: Menu entry on the task card

Wires the action into the card's existing `...` menu, collapsing between a flat button and a submenu.

**Files:**
- Modify: `Devtail/Features/Workspace/Views/Components/TaskBoardTabView.swift:218-239`

**Interfaces:**
- Consumes: `WorkspaceSession.sendTask(title:toAgent:)` and `WorkspaceSession.liveAgents` from Task 2.
- Produces: nothing — terminal task.

`TaskBoardTabView` already holds `let session: WorkspaceSession` (line 22) and
derives `store` from it (line 32), so the action is reachable with no new
plumbing. The card row is a private subview in the same file — if it does not
already receive `session`, pass it down from `TaskBoardTabView` the same way
the file already passes `store`. Do NOT introduce an environment object.

- [ ] **Step 1: Add the menu entry**

In the `Menu { ... }` block at line 218, insert immediately after `Button("Edit") { beginRename(task) }`:

```swift
                let liveAgents = session.liveAgents
                if liveAgents.count == 1 {
                    Button("Send to agent") {
                        session.sendTask(title: task.title, toAgent: liveAgents[0].id)
                    }
                } else if liveAgents.count > 1 {
                    Menu("Send to") {
                        ForEach(liveAgents) { agent in
                            Button(agent.title) {
                                session.sendTask(title: task.title, toAgent: agent.id)
                            }
                        }
                    }
                }
```

Zero live agents renders nothing — no entry, no disabled row.

- [ ] **Step 2: Run the full suite**

Run: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' 2>&1 | tail -20`
Expected: PASS, previous count + 4 (the Task 2 tests), zero failures.

- [ ] **Step 3: Commit**

```bash
git add Devtail/Features/Workspace/Views/Components/TaskBoardTabView.swift
git commit -m "feat(tasks): add send-to-agent action to the task card menu"
```

- [ ] **Step 4: User visual checkpoint**

The bracketed-paste escape sequences need a live PTY, so the last mile is
verified by hand, not by tests. Ask the user to build, open a workspace with a
task board, and confirm:

1. One agent tab open → the menu shows a flat `Send to agent`.
2. Clicking it switches to the agent tab with `Tarea del board: <title>` sitting
   in the prompt, NOT submitted.
3. A second agent tab open (`+` chip) → the menu shows `Send to ▸` with both.
4. Sending to `agent 2` lands in `agent 2`, not in `agent`.

---

## Self-Review

**Spec coverage:**
- Generalize send channel → Task 1.
- Direct write through the protocol → Task 1 (protocol) + Task 2 (caller).
- Menu entry with collapse rules → Task 3.
- Exited agents excluded → Task 2 (`liveAgents`) + Task 3 (consumption).
- Prompt format → Task 2.
- Tab selection → Task 2.
- Testing list → Task 2 covers all five unit-testable items; the PTY seam is Task 3 Step 5.

**Placeholders:** none — every code step carries real code.

**Type consistency:** `sendBracketedText(_:)` is named identically in the protocol, the view, the engine, and the mock. `sendTask(title:toAgent:)` and `liveAgents` match between Task 2's definition and Task 3's use.

**Verified before execution:** `TaskBoardTabView` already holds `session: WorkspaceSession` (line 22), so Task 3 needs no plumbing. The bracketed-paste seam remains the one thing tests cannot reach — that is the checkpoint's job, stated explicitly rather than left implicit.
