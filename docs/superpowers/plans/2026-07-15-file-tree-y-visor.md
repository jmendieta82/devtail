# File tree y visor embebido (Ciclo 2) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el placeholder de la columna derecha por un file tree lazy cuyo click en archivo abre un visor read-only con syntax highlighting como tab del centro.

**Architecture:** `selectedTab` migra de `UUID?` a `enum WorkspaceTab` (terminal / process / file). La sesión gana `openFiles` + open/close y un `FileTreeStore` lazy (protocolo `DirectoryLister` inyectable). El visor es `NSTextView` read-only con gutter `NSRulerView`, alimentado por `HighlighterSwift` confinado a `@MainActor` con guardrails de tamaño. La retención ZStack de terminales NO cambia; las tabs de archivo se renderizan condicionalmente.

**Tech Stack:** Swift 6 (MainActor default isolation), SwiftUI + AppKit (NSTextView/NSRulerView), SPM `HighlighterSwift` 3.1.0 (`import Highlighter`), swift-testing.

**Spec:** `docs/superpowers/specs/2026-07-15-file-tree-y-visor-design.md`

## Global Constraints

- Branch: `feat/file-tree-y-visor` (desde `main` 00d941e; merge solo tras checkpoint manual de Javier).
- Suite base: **288 casos, 0 fallos**. Ningún task commitea con la suite rota. Comando: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet` (focalizado: `-only-testing:DevtailTests/<Suite>`).
- **PROTOCOLO OOM**: antes de CUALQUIER `xcodebuild`: `pgrep -fl xcodebuild || echo clear` debe dar `clear`. NUNCA dos builds solapados. Nota: el primer build tras agregar el SPM compila HighlighterSwift desde cero — igual UN solo runner.
- **Conteo de tests**: `xcodebuild -quiet` pierde ocasionalmente una línea "passed" (artefacto conocido) — juzgar por exit code y "0 failed", no por conteo exacto de líneas.
- Swift 6 gotcha (mordió 2 veces): un `init()` `@MainActor`-aislado NO puede ser valor por defecto de parámetro. Con `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` esto incluye inits de structs propios — **no usar `lister: DirectoryLister = FileManagerDirectoryLister()` como default param**; inyectar explícito.
- Archivos Swift nuevos se auto-incluyen (PBXFileSystemSynchronizedRootGroup) — pbxproj solo se toca para el SPM.
- UI strings en inglés hardcodeado. Tokens visuales SIEMPRE de `DevtailTokens` (fuente mono: `DevtailTokens.Typography.mono` = UbuntuMono-Regular 13).
- Commits: Conventional Commits, SIN atribución de AI.
- La retención ZStack de terminales (opacity/allowsHitTesting, nunca desmontar) es intocable.

---

### Task 0: Branch

- [ ] **Step 1:**

```bash
cd /Volumes/Datos/Frelancer/DEVTAIL/Devtail
git checkout main && git checkout -b feat/file-tree-y-visor
```

---

### Task 1: Migración `selectedTab` → `WorkspaceTab`

**Files:**
- Create: `Devtail/Features/Workspace/Models/WorkspaceTab.swift`
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift` (`WorkspaceSession.selectedTab`)
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift` (`tabRow`, `tabButton`, `terminalArea`, `deadShellOverlay` condition)
- Modify: `Devtail/Features/Workspace/Views/Components/WorkspaceDashboardColumn.swift` (`processesSection` closures)
- Test: actualizar todo test que referencie `selectedTab` (`rg -n "selectedTab" Devtail DevtailTests`)

**Interfaces:**
- Produces: `enum WorkspaceTab: Hashable { case terminal; case process(UUID); case file(String) }` y `WorkspaceSession.selectedTab: WorkspaceTab` (default `.terminal`) — los usan Tasks 2 y 7.

- [ ] **Step 1: Test que falla** — en `WorkspaceSessionsHolderTests.swift` agregar:

```swift
@Test func openSessionStartsOnTerminalTab() {
    let session = holder.openSession(for: project)   // mismo setup que tests vecinos
    #expect(session.selectedTab == .terminal)
}
```

- [ ] **Step 2: Verificar RED**

```bash
pgrep -fl xcodebuild || echo clear
xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet -only-testing:DevtailTests/WorkspaceSessionsHolderTests
```
Expected: FAIL de compilación (`.terminal` no existe).

- [ ] **Step 3: Implementar**

`WorkspaceTab.swift`:

```swift
/// Identity of a center-column tab in the workspace window.
enum WorkspaceTab: Hashable {
    case terminal
    case process(UUID)
    /// Absolute path of an open file (read-only viewer tab).
    case file(String)
}
```

En `WorkspaceSession`: `var selectedTab: UUID?` → `var selectedTab: WorkspaceTab = .terminal` (actualizar su doc-comment).

En `WorkspaceRootView`:

```swift
private var tabRow: some View {
    HStack(spacing: DevtailTokens.Spacing.gapSmall) {
        tabButton(title: "terminal", tab: .terminal)
        ForEach(session.supervisor.processes) { process in
            tabButton(title: process.name, tab: .process(process.id))
        }
        Spacer()
    }
    // modificadores existentes sin cambios
}

private func tabButton(title: String, tab: WorkspaceTab) -> some View {
    Button(title) { session.selectedTab = tab }
        .buttonStyle(.plain)
        .font(DevtailTokens.Typography.caption)
        .foregroundStyle(session.selectedTab == tab ? .primary : .secondary)
}
```

En `terminalArea`: `session.selectedTab == nil` → `== .terminal`; `session.selectedTab == process.id` → `== .process(process.id)` (opacity Y allowsHitTesting); la condición del `deadShellOverlay`: `session.selectedTab == .terminal && session.interactiveExited`.

En `WorkspaceDashboardColumn.processesSection`: `isSelected: session.selectedTab == .process(process.id)` y `onSelect: { session.selectedTab = .process(process.id) }`.

Actualizar cualquier otro hit del `rg` (tests que asignen/asserten UUIDs de proceso: envolver en `.process(...)`).

- [ ] **Step 4: Verificar GREEN + suite completa**

```bash
pgrep -fl xcodebuild || echo clear
xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet
```
Expected: exit 0, 0 failed (289 casos: 288 + el nuevo).

- [ ] **Step 5: Commit** — `git add -A Devtail DevtailTests && git commit -m "refactor(workspace): tab selection becomes a typed WorkspaceTab enum"`

---

### Task 2: `OpenFile` + open/close en la sesión

**Files:**
- Create: `Devtail/Features/Workspace/Models/OpenFile.swift`
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift` (`WorkspaceSession`)
- Test: Create `DevtailTests/Features/Workspace/WorkspaceSessionOpenFilesTests.swift`

**Interfaces:**
- Consumes: `WorkspaceTab.file(String)` (Task 1).
- Produces: `OpenFile { path, id, name }`, `WorkspaceSession.openFiles: [OpenFile]`, `openFile(at:)`, `closeFile(at:)` — los usan Tasks 6 y 7.

- [ ] **Step 1: Tests que fallan** — `WorkspaceSessionOpenFilesTests.swift` (mismo setup de sesión que `WorkspaceSessionsHolderTests`, extraer helper local):

```swift
import Foundation
import Testing
@testable import Devtail

@MainActor
struct WorkspaceSessionOpenFilesTests {
    // helper makeSession() con MockTerminalEngine, como WorkspaceSessionsHolderTests

    @Test func openAppendsAndSelects() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift")
        #expect(s.openFiles.map(\.path) == ["/tmp/a.swift"])
        #expect(s.selectedTab == .file("/tmp/a.swift"))
    }

    @Test func openIsIdempotentAndReselects() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift")
        s.openFile(at: "/tmp/b.swift")
        s.openFile(at: "/tmp/a.swift")
        #expect(s.openFiles.map(\.path) == ["/tmp/a.swift", "/tmp/b.swift"])
        #expect(s.selectedTab == .file("/tmp/a.swift"))
    }

    @Test func closeSelectedSelectsPreviousNeighbor() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift"); s.openFile(at: "/tmp/b.swift"); s.openFile(at: "/tmp/c.swift")
        s.closeFile(at: "/tmp/b.swift")   // b sigue seleccionado? no: c es el seleccionado
        s.openFile(at: "/tmp/b.swift")    // reabrir y seleccionar b
        s.closeFile(at: "/tmp/b.swift")
        #expect(s.selectedTab == .file("/tmp/c.swift"))
    }

    @Test func closeSelectedFirstSelectsNext() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift"); s.openFile(at: "/tmp/b.swift")
        s.openFile(at: "/tmp/a.swift")
        s.closeFile(at: "/tmp/a.swift")
        #expect(s.selectedTab == .file("/tmp/b.swift"))
    }

    @Test func closeLastFileSelectsTerminal() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift")
        s.closeFile(at: "/tmp/a.swift")
        #expect(s.openFiles.isEmpty)
        #expect(s.selectedTab == .terminal)
    }

    @Test func closeUnselectedKeepsSelection() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift"); s.openFile(at: "/tmp/b.swift")
        s.closeFile(at: "/tmp/a.swift")
        #expect(s.selectedTab == .file("/tmp/b.swift"))
    }

    @Test func closeUnknownPathIsNoOp() {
        let s = makeSession()
        s.openFile(at: "/tmp/a.swift")
        s.closeFile(at: "/tmp/zzz.swift")
        #expect(s.openFiles.count == 1)
    }
}
```

- [ ] **Step 2: RED** (focalizado a la suite nueva). Expected: FAIL de compilación.

- [ ] **Step 3: Implementar**

`OpenFile.swift`:

```swift
/// A file open in the workspace center column (read-only viewer tab).
struct OpenFile: Identifiable, Hashable {
    let path: String
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
}
```

En `WorkspaceSession`:

```swift
private(set) var openFiles: [OpenFile] = []

func openFile(at path: String) {
    if !openFiles.contains(where: { $0.path == path }) {
        openFiles.append(OpenFile(path: path))
    }
    selectedTab = .file(path)
}

func closeFile(at path: String) {
    guard let index = openFiles.firstIndex(where: { $0.path == path }) else { return }
    openFiles.remove(at: index)
    guard selectedTab == .file(path) else { return }
    if openFiles.isEmpty {
        selectedTab = .terminal
    } else {
        selectedTab = .file(openFiles[max(0, index - 1)].path)
    }
}
```

- [ ] **Step 4: GREEN focalizado + suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 5: Commit** — `git commit -m "feat(workspace): open-file tab state on the session"`

---

### Task 3: `DirectoryLister` + `FileTreeStore`

**Files:**
- Create: `Devtail/Features/Workspace/Services/DirectoryLister.swift`
- Create: `Devtail/Features/Workspace/Stores/FileTreeStore.swift`
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift` (la sesión gana `let fileTree: FileTreeStore`)
- Test: Create `DevtailTests/Features/Workspace/FileTreeStoreTests.swift` (+ `MockDirectoryLister` en el mismo archivo)

**Interfaces:**
- Produces: `DirectoryEntry { name, url, isDirectory }`, `protocol DirectoryLister { func list(_ directory: URL) throws -> [DirectoryEntry] }`, `FileManagerDirectoryLister`, `FileTreeNode { entry, depth, isExpanded, children, loadError }`, `FileTreeStore { rootNodes, rootError, loadRootIfNeeded(), toggleExpansion(of:) }`, `WorkspaceSession.fileTree` — los usa Task 6.

- [ ] **Step 1: Tests que fallan** — `FileTreeStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import Devtail

@MainActor
final class MockDirectoryLister: DirectoryLister {
    var entriesByPath: [String: [DirectoryEntry]] = [:]
    var errorPaths: Set<String> = []
    private(set) var listedPaths: [String] = []

    func list(_ directory: URL) throws -> [DirectoryEntry] {
        listedPaths.append(directory.path)
        if errorPaths.contains(directory.path) {
            throw NSError(domain: "mock", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        }
        return entriesByPath[directory.path] ?? []
    }
}

@MainActor
struct FileTreeStoreTests {
    private func dir(_ path: String) -> DirectoryEntry {
        DirectoryEntry(name: (path as NSString).lastPathComponent, url: URL(fileURLWithPath: path), isDirectory: true)
    }
    private func file(_ path: String) -> DirectoryEntry {
        DirectoryEntry(name: (path as NSString).lastPathComponent, url: URL(fileURLWithPath: path), isDirectory: false)
    }

    @Test func loadRootListsOnceAndIsIdempotent() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [file("/root/a.txt")]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        store.loadRootIfNeeded()
        #expect(mock.listedPaths == ["/root"])
        #expect(store.rootNodes?.count == 1)
    }

    @Test func relativeRootFailsClosed() {
        // URL(string: "file:...") yields a genuinely relative path, unlike
        // URL(fileURLWithPath: "") which resolves against CWD (see
        // GitBranchDetectorTests.relativeURLReturnsNil).
        let store = FileTreeStore(root: URL(string: "file:some/relative/dir")!, lister: MockDirectoryLister())
        store.loadRootIfNeeded()
        #expect(store.rootNodes == nil)
        #expect(store.rootError != nil)
    }

    @Test func expandLoadsChildrenLazilyOnce() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [dir("/root/sub")]
        mock.entriesByPath["/root/sub"] = [file("/root/sub/x.swift")]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        let sub = store.rootNodes![0]
        #expect(sub.children == nil)
        store.toggleExpansion(of: sub)          // expand → carga
        store.toggleExpansion(of: sub)          // collapse
        store.toggleExpansion(of: sub)          // re-expand → NO re-lista
        #expect(mock.listedPaths.filter { $0 == "/root/sub" }.count == 1)
        #expect(sub.children?.count == 1)
    }

    @Test func expandErrorIsPerNode() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [dir("/root/locked"), file("/root/ok.txt")]
        mock.errorPaths = ["/root/locked"]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        let locked = store.rootNodes![0]
        store.toggleExpansion(of: locked)
        #expect(locked.loadError != nil)
        #expect(store.rootError == nil)
    }

    @Test func toggleOnFileIsNoOp() {
        let mock = MockDirectoryLister()
        mock.entriesByPath["/root"] = [file("/root/a.txt")]
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        store.loadRootIfNeeded()
        let node = store.rootNodes![0]
        store.toggleExpansion(of: node)
        #expect(node.isExpanded == false)
        #expect(mock.listedPaths == ["/root"])
    }

    @Test func depthCapStopsLoading() {
        let mock = MockDirectoryLister()
        let store = FileTreeStore(root: URL(fileURLWithPath: "/root"), lister: mock)
        let deep = FileTreeNode(entry: dir("/root/deep"), depth: FileTreeStore.maxDepth)
        store.toggleExpansion(of: deep)
        #expect(deep.children == nil)
        #expect(deep.loadError != nil)
    }

    @Test func realListerSortsDirsFirstThenNameAndIncludesHidden() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-filetree-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("zdir"), withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("Alpha.txt"))
        try Data().write(to: folder.appendingPathComponent(".hidden"))
        let entries = try FileManagerDirectoryLister().list(folder)
        #expect(entries.map(\.name) == ["zdir", ".hidden", "Alpha.txt"])
        #expect(entries[0].isDirectory)
    }
}
```

- [ ] **Step 2: RED** (focalizado `FileTreeStoreTests`). Expected: FAIL de compilación.

- [ ] **Step 3: Implementar**

`DirectoryLister.swift`:

```swift
import Foundation

struct DirectoryEntry: Hashable {
    let name: String
    let url: URL
    let isDirectory: Bool
}

protocol DirectoryLister {
    func list(_ directory: URL) throws -> [DirectoryEntry]
}

struct FileManagerDirectoryLister: DirectoryLister {
    func list(_ directory: URL) throws -> [DirectoryEntry] {
        try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            .map { url in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return DirectoryEntry(name: url.lastPathComponent, url: url, isDirectory: isDirectory)
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }
}
```

`FileTreeStore.swift` (defensas del incidente GitBranchDetector: path absoluto, cap de profundidad):

```swift
import Foundation

@Observable
final class FileTreeNode: Identifiable {
    let entry: DirectoryEntry
    let depth: Int
    var isExpanded = false
    var children: [FileTreeNode]?      // nil = never loaded
    var loadError: String?

    var id: String { entry.url.path }
    var isDotfile: Bool { entry.name.hasPrefix(".") }

    init(entry: DirectoryEntry, depth: Int) {
        self.entry = entry
        self.depth = depth
    }
}

@Observable
final class FileTreeStore {
    /// No real project is deeper than this; bail instead of walking forever.
    static let maxDepth = 32

    let root: URL
    private let lister: DirectoryLister
    private(set) var rootNodes: [FileTreeNode]?
    private(set) var rootError: String?

    init(root: URL, lister: DirectoryLister) {
        self.root = root
        self.lister = lister
    }

    func loadRootIfNeeded() {
        guard rootNodes == nil, rootError == nil else { return }
        // Relative URLs never converge when walked (see GitBranchDetector incident).
        guard root.path.hasPrefix("/") else {
            rootError = "Invalid project root"
            return
        }
        do {
            rootNodes = try lister.list(root).map { FileTreeNode(entry: $0, depth: 0) }
        } catch {
            rootError = error.localizedDescription
        }
    }

    func toggleExpansion(of node: FileTreeNode) {
        guard node.entry.isDirectory else { return }
        node.isExpanded.toggle()
        guard node.isExpanded, node.children == nil else { return }
        guard node.depth < Self.maxDepth else {
            node.loadError = "Folder is too deeply nested"
            return
        }
        do {
            node.children = try lister.list(node.entry.url).map {
                FileTreeNode(entry: $0, depth: node.depth + 1)
            }
            node.loadError = nil
        } catch {
            node.loadError = error.localizedDescription
        }
    }
}
```

En `WorkspaceSession`: agregar `let fileTree: FileTreeStore`, inicializado en su `init` con `FileTreeStore(root: root, lister: FileManagerDirectoryLister())` (construcción explícita DENTRO del init — no como default param, por el gotcha de MainActor).

- [ ] **Step 4: GREEN focalizado + suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 5: Commit** — `git commit -m "feat(workspace): lazy file tree store behind an injectable directory lister"`

---

### Task 4: SPM HighlighterSwift + `CodeLanguageMap` + `FileContentLoader` + `CodeHighlighter`

**Files:**
- Modify: `Devtail.xcodeproj/project.pbxproj` (4 bloques, espejo del patrón SwiftTerm)
- Create: `Devtail/Features/Workspace/Services/CodeLanguageMap.swift`
- Create: `Devtail/Features/Workspace/Services/FileContentLoader.swift`
- Create: `Devtail/Features/Workspace/Services/CodeHighlighter.swift`
- Test: Create `DevtailTests/Features/Workspace/CodeLanguageMapTests.swift`, `DevtailTests/Features/Workspace/FileContentLoaderTests.swift`, `DevtailTests/Features/Workspace/CodeHighlighterTests.swift`

**Interfaces:**
- Produces: `CodeLanguageMap.language(forExtension:) -> String?`; `FileViewerContent` (`.text(String, language: String?, highlightable: Bool)` / `.binary` / `.tooLarge(Int)` / `.unreadable(String)`); `FileContentLoader.load(path:) -> FileViewerContent`; `CodeHighlighter.shared` (`@MainActor`) con `highlight(_:language:) -> NSAttributedString?` y `backgroundColor: NSColor` — los usa Task 5.

- [ ] **Step 1: SPM en pbxproj** — espejo EXACTO del patrón SwiftTerm existente (líneas de referencia en el pbxproj actual: XCRemoteSwiftPackageReference L477-484, XCSwiftPackageProductDependency L488-492, PBXBuildFile L10, y las tres listas: `packageReferences` L156, `packageProductDependencies` L120-122, Frameworks phase L49-56). Agregar con IDs nuevos únicos (verificar con `rg` que no existan):

```
DE5717E2000000000000A003 /* XCRemoteSwiftPackageReference "HighlighterSwift" */ = {
    isa = XCRemoteSwiftPackageReference;
    repositoryURL = "https://github.com/smittytone/HighlighterSwift";
    requirement = {
        kind = upToNextMajorVersion;
        minimumVersion = 3.1.0;
    };
};
DE5717E3000000000000A004 /* Highlighter */ = {
    isa = XCSwiftPackageProductDependency;
    package = DE5717E2000000000000A003 /* XCRemoteSwiftPackageReference "HighlighterSwift" */;
    productName = Highlighter;
};
4399E48B300702B4006E97E4 /* Highlighter in Frameworks */ = {isa = PBXBuildFile; productRef = DE5717E3000000000000A004 /* Highlighter */; };
```

y las tres inserciones en las listas (junto a las entradas SwiftTerm). Solo target Devtail (los tests importan via `@testable import Devtail`).

- [ ] **Step 2: Tests que fallan**

`CodeLanguageMapTests.swift`:

```swift
import Testing
@testable import Devtail

struct CodeLanguageMapTests {
    @Test func knownExtensions() {
        #expect(CodeLanguageMap.language(forExtension: "swift") == "swift")
        #expect(CodeLanguageMap.language(forExtension: "ts") == "typescript")
        #expect(CodeLanguageMap.language(forExtension: "yml") == "yaml")
        #expect(CodeLanguageMap.language(forExtension: "html") == "xml")
    }
    @Test func caseInsensitive() {
        #expect(CodeLanguageMap.language(forExtension: "SWIFT") == "swift")
    }
    @Test func unknownReturnsNilForAutoDetect() {
        #expect(CodeLanguageMap.language(forExtension: "xyzzy") == nil)
    }
}
```

`FileContentLoaderTests.swift` (temp files, patrón `temporaryDirectory + UUID + defer removeItem`):

```swift
import Foundation
import Testing
@testable import Devtail

struct FileContentLoaderTests {
    private func makeFile(_ name: String, _ data: Data) throws -> (URL, () -> Void) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-loader-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url)
        return (url, { try? FileManager.default.removeItem(at: folder) })
    }

    @Test func smallSwiftFileIsHighlightableText() throws {
        let (url, cleanup) = try makeFile("a.swift", Data("let x = 1\n".utf8))
        defer { cleanup() }
        #expect(FileContentLoader.load(path: url.path) == .text("let x = 1\n", language: "swift", highlightable: true))
    }

    @Test func nulByteMeansBinary() throws {
        let (url, cleanup) = try makeFile("blob.bin", Data([0x41, 0x00, 0x42]))
        defer { cleanup() }
        #expect(FileContentLoader.load(path: url.path) == .binary)
    }

    @Test func overHighlightLimitIsPlainText() throws {
        let big = String(repeating: "a", count: FileContentLoader.highlightByteLimit + 1)
        let (url, cleanup) = try makeFile("big.txt", Data(big.utf8))
        defer { cleanup() }
        if case .text(_, _, let highlightable) = FileContentLoader.load(path: url.path) {
            #expect(highlightable == false)
        } else { Issue.record("expected .text") }
    }

    @Test func overPlainLimitIsTooLarge() throws {
        let (url, cleanup) = try makeFile("huge.txt", Data(count: FileContentLoader.plainByteLimit + 1))
        defer { cleanup() }
        // Data(count:) es todo ceros → binario ganaría; usar bytes 'a'
        try Data(String(repeating: "a", count: FileContentLoader.plainByteLimit + 1).utf8).write(to: url)
        if case .tooLarge = FileContentLoader.load(path: url.path) {} else { Issue.record("expected .tooLarge") }
    }

    @Test func missingFileIsUnreadable() {
        if case .unreadable = FileContentLoader.load(path: "/nonexistent/nope.txt") {} else { Issue.record("expected .unreadable") }
    }

    @Test func manyLinesDisableHighlight() throws {
        let lines = String(repeating: "x\n", count: FileContentLoader.highlightLineLimit + 1)
        let (url, cleanup) = try makeFile("lines.txt", Data(lines.utf8))
        defer { cleanup() }
        if case .text(_, _, let highlightable) = FileContentLoader.load(path: url.path) {
            #expect(highlightable == false)
        } else { Issue.record("expected .text") }
    }
}
```

`CodeHighlighterTests.swift` (smoke — carga el JS real del bundle SPM):

```swift
import Testing
@testable import Devtail

@MainActor
struct CodeHighlighterTests {
    @Test func highlightsSwiftSnippet() {
        let result = CodeHighlighter.shared.highlight("let x = 1", language: "swift")
        #expect(result != nil)
        #expect(result!.length > 0)
    }
    @Test func backgroundColorAvailableAfterUse() {
        _ = CodeHighlighter.shared.highlight("x", language: nil)
        _ = CodeHighlighter.shared.backgroundColor   // no crash, no nil-force
    }
}
```

- [ ] **Step 3: RED** (build fallará hasta implementar; el SPM resolve del primer build tarda — un solo runner).

- [ ] **Step 4: Implementar**

`CodeLanguageMap.swift`:

```swift
/// File extension → highlight.js language name. Unknown → nil (engine auto-detect).
enum CodeLanguageMap {
    private static let map: [String: String] = [
        "swift": "swift", "ts": "typescript", "tsx": "typescript",
        "js": "javascript", "jsx": "javascript", "mjs": "javascript",
        "py": "python", "rb": "ruby", "go": "go", "rs": "rust",
        "java": "java", "kt": "kotlin", "cs": "csharp",
        "json": "json", "yml": "yaml", "yaml": "yaml", "toml": "ini",
        "md": "markdown", "sh": "bash", "zsh": "bash", "bash": "bash",
        "html": "xml", "htm": "xml", "xml": "xml", "plist": "xml",
        "css": "css", "scss": "scss", "sql": "sql",
        "c": "c", "h": "c", "cpp": "cpp", "hpp": "cpp", "m": "objectivec",
        "dockerfile": "dockerfile", "gradle": "gradle", "graphql": "graphql",
    ]

    static func language(forExtension ext: String) -> String? {
        map[ext.lowercased()]
    }
}
```

`FileContentLoader.swift`:

```swift
import Foundation

enum FileViewerContent: Equatable {
    case text(String, language: String?, highlightable: Bool)
    case binary
    case tooLarge(Int)
    case unreadable(String)
}

/// Loads a file for the read-only viewer with VS Code-style guardrails.
enum FileContentLoader {
    static let highlightByteLimit = 512 * 1024
    static let highlightLineLimit = 10_000
    static let plainByteLimit = 5 * 1024 * 1024

    static func load(path: String) -> FileViewerContent {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return .unreadable(error.localizedDescription)
        }
        if data.count > plainByteLimit { return .tooLarge(data.count) }
        if data.prefix(8192).contains(0) { return .binary }
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            return .binary
        }
        let language = CodeLanguageMap.language(forExtension: url.pathExtension)
        let lineCount = text.lazy.filter { $0 == "\n" }.count + 1
        let highlightable = data.count <= highlightByteLimit && lineCount <= highlightLineLimit
        return .text(text, language: language, highlightable: highlightable)
    }
}
```

`CodeHighlighter.swift` (si el compilador exige aislamiento del import: `@preconcurrency import Highlighter`):

```swift
import AppKit
import Highlighter

/// MainActor-confined wrapper around HighlighterSwift (JSContext is not Sendable).
/// Cost per file is bounded by FileContentLoader's highlight guardrails.
@MainActor
final class CodeHighlighter {
    static let shared = CodeHighlighter()

    private var engine: Highlighter?
    private var isSetUp = false

    private init() {}

    var backgroundColor: NSColor {
        setUpIfNeeded()
        return engine?.theme?.themeBackgroundColour ?? .textBackgroundColor
    }

    func highlight(_ code: String, language: String?) -> NSAttributedString? {
        setUpIfNeeded()
        return engine?.highlight(code, as: language, doFastRender: true)
    }

    private func setUpIfNeeded() {
        guard !isSetUp else { return }
        isSetUp = true
        engine = Highlighter()
        engine?.setTheme("material-palenight", withFont: "UbuntuMono-Regular", ofSize: 13)
    }
}
```

- [ ] **Step 5: GREEN focalizado (3 suites nuevas) + suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 6: Commit** — `git add -A Devtail DevtailTests Devtail.xcodeproj && git commit -m "feat(viewer): HighlighterSwift engine, language map and load guardrails"`

---

### Task 5: Visor — `CodeViewerView` + `LineNumberRulerView` + `FileViewerTabView`

**Files:**
- Create: `Devtail/Features/Workspace/Views/Components/CodeViewerView.swift` (incluye `LineNumberRulerView`, acoplados)
- Create: `Devtail/Features/Workspace/Views/Components/FileViewerTabView.swift`

**Interfaces:**
- Consumes: `FileContentLoader`, `CodeHighlighter`, `CodeLanguageMap` (Task 4), tokens `DevtailTokens.Typography.mono`.
- Produces: `FileViewerTabView(path: String)` — la usa Task 7.

- [ ] **Step 1: `CodeViewerView.swift`**

```swift
import AppKit
import SwiftUI

/// Read-only code surface: NSTextView + line-number ruler.
struct CodeViewerView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let backgroundColor: NSColor

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasVerticalRuler = true
        scrollView.verticalRulerView = LineNumberRulerView(textView: textView)
        scrollView.rulersVisible = true
        scrollView.drawsBackground = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributedText)
        textView.backgroundColor = backgroundColor
        scrollView.backgroundColor = backgroundColor
        (scrollView.verticalRulerView as? LineNumberRulerView)?.needsDisplay = true
    }
}

/// Classic macOS line-number gutter (NSRulerView over the scroll view).
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44
        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange),
            name: NSText.didChangeNotification, object: textView
        )
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func textDidChange() { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        NSColor.textBackgroundColor.withAlphaComponent(0).setFill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "UbuntuMono-Regular", size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]

        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let text = textView.string as NSString
        var lineNumber = text.substring(to: layoutManager.characterIndexForGlyph(at: visibleGlyphs.location))
            .components(separatedBy: "\n").count

        var glyphIndex = visibleGlyphs.location
        while glyphIndex < NSMaxRange(visibleGlyphs) {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            let isLineStart = charRange.location == 0
                || text.character(at: charRange.location - 1) == unichar(10)
            if isLineStart {
                let label = "\(lineNumber)" as NSString
                let size = label.size(withAttributes: attributes)
                let y = convert(NSPoint(x: 0, y: lineRect.minY), from: textView).y
                label.draw(at: NSPoint(x: ruleThickness - size.width - 6, y: y + textView.textContainerInset.height),
                           withAttributes: attributes)
                lineNumber += 1
            }
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }
}
```

Nota para el implementador: el dibujo del gutter es la parte con más riesgo de off-by-one visual (conversión de coordenadas ruler↔textView, inset, primera línea visible). Ajustar hasta que los números alineen con las líneas en una preview/manual run — el contrato es: números alineados, actualizados al scrollear, sin participar de la selección de texto.

- [ ] **Step 2: `FileViewerTabView.swift`**

```swift
import SwiftUI

/// Center-column tab content for an open file (read-only).
struct FileViewerTabView: View {
    let path: String

    @State private var content: FileViewerContent?

    var body: some View {
        Group {
            switch content {
            case nil:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .binary:
                placeholder(icon: "doc.zipper", title: "Binary file", detail: "This file can't be displayed.")
            case .tooLarge(let bytes):
                placeholder(icon: "doc.badge.ellipsis", title: "File too large",
                            detail: "\(bytes / (1024 * 1024)) MB exceeds the viewer limit.")
            case .unreadable(let reason):
                placeholder(icon: "exclamationmark.triangle", title: "Can't read file", detail: reason)
            case .text(let text, let language, let highlightable):
                viewer(text: text, language: language, highlightable: highlightable)
            }
        }
        .task(id: path) { content = FileContentLoader.load(path: path) }
    }

    private func viewer(text: String, language: String?, highlightable: Bool) -> some View {
        let attributed: NSAttributedString
        if highlightable, let highlighted = CodeHighlighter.shared.highlight(text, language: language) {
            attributed = highlighted
        } else {
            attributed = NSAttributedString(string: text, attributes: [
                .font: NSFont(name: "UbuntuMono-Regular", size: 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.labelColor,
            ])
        }
        return CodeViewerView(
            attributedText: attributed,
            backgroundColor: highlightable ? CodeHighlighter.shared.backgroundColor : .textBackgroundColor
        )
    }

    private func placeholder(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: Suite completa** (sin tests nuevos — capa de vista; los servicios ya están testeados). Expected: exit 0, 0 failed.
- [ ] **Step 4: Commit** — `git commit -m "feat(viewer): read-only code viewer with line-number gutter"`

---

### Task 6: `FileTreeColumn` (UI del tree)

**Files:**
- Create: `Devtail/Features/Workspace/Views/Components/FileTreeColumn.swift`
- Delete: `Devtail/Features/Workspace/Views/Components/FileTreePlaceholderColumn.swift`
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift` (columna derecha)

**Interfaces:**
- Consumes: `WorkspaceSession.fileTree` (Task 3), `session.openFile(at:)` (Task 2), `SectionHeader`, `DevtailTokens`.
- Produces: `FileTreeColumn(session: WorkspaceSession)`.

- [ ] **Step 1: Implementar**

```swift
import SwiftUI

/// Right column: lazy project file tree. File clicks open viewer tabs.
struct FileTreeColumn: View {
    let session: WorkspaceSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                SectionHeader(title: "Files")
                if let error = session.fileTree.rootError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                } else if let nodes = session.fileTree.rootNodes {
                    ForEach(nodes) { node in
                        FileTreeNodeRow(node: node, session: session)
                    }
                }
            }
            .padding(DevtailTokens.Spacing.cardPadding)
        }
        .onAppear { session.fileTree.loadRootIfNeeded() }
    }
}

private struct FileTreeNodeRow: View {
    let node: FileTreeNode
    let session: WorkspaceSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: activate) {
                HStack(spacing: 4) {
                    if node.entry.isDirectory {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    } else {
                        Spacer().frame(width: 10)
                    }
                    Image(systemName: node.entry.isDirectory ? "folder" : "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    Text(node.entry.name)
                        .font(DevtailTokens.Typography.caption)
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)
            .opacity(node.isDotfile ? 0.5 : 1)
            .padding(.leading, CGFloat(node.depth) * 12)

            if let error = node.loadError, node.isExpanded {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
                    .padding(.leading, CGFloat(node.depth + 1) * 12)
            }
            if node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileTreeNodeRow(node: child, session: session)
                }
            }
        }
    }

    private func activate() {
        if node.entry.isDirectory {
            session.fileTree.toggleExpansion(of: node)
        } else {
            session.openFile(at: node.entry.url.path)
        }
    }
}
```

- [ ] **Step 2: Reemplazar en `WorkspaceRootView`**: `FileTreePlaceholderColumn()` → `FileTreeColumn(session: session)` (mismo `.frame(minWidth: 220, maxWidth: 300)`); borrar `FileTreePlaceholderColumn.swift`.
- [ ] **Step 3: Suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 4: Commit** — `git commit -m "feat(workspace): lazy file tree column replaces placeholder"`

---

### Task 7: Tabs de archivo en el centro

**Files:**
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift` (`tabRow` + área central)

**Interfaces:**
- Consumes: `session.openFiles`/`closeFile(at:)` (Task 2), `FileViewerTabView` (Task 5), `WorkspaceTab.file` (Task 1).

- [ ] **Step 1: `tabRow`** — después del `ForEach` de procesos, antes del `Spacer()`:

```swift
ForEach(session.openFiles) { file in
    fileTab(for: file)
}
```

```swift
private func fileTab(for file: OpenFile) -> some View {
    HStack(spacing: 4) {
        Button(file.name) { session.selectedTab = .file(file.path) }
            .buttonStyle(.plain)
            .font(DevtailTokens.Typography.caption)
            .foregroundStyle(session.selectedTab == .file(file.path) ? .primary : .secondary)
        Button {
            session.closeFile(at: file.path)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Área central** — dentro del `ZStack` de `terminalArea`, después del `ForEach` de procesos (los terminales quedan montados con opacity 0 cuando la selección es `.file`; el visor se monta condicionalmente — sin retención, por diseño):

```swift
if case .file(let path) = session.selectedTab {
    FileViewerTabView(path: path)
}
```

(La condición del `deadShellOverlay` ya exige `.terminal`, no cambia.)

- [ ] **Step 3: Suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 4: Commit** — `git commit -m "feat(workspace): file viewer tabs alongside terminal and process tabs"`

---

### Task 8: Ledger, suite final y checkpoint manual

- [ ] **Step 1**: Append a `.superpowers/sdd/progress.md` la sección del Ciclo 2 con estado por task (el ledger es scratch git-ignored — no commitear).
- [ ] **Step 2**: Suite completa final; registrar conteo (esperado: 288 + ~17 nuevos).
- [ ] **Step 3: USER CHECKPOINT (Javier) — bloquea merge**:
  1. Tree en la columna derecha: carpetas expanden lazy, orden carpetas-primero, dotfiles atenuados, carpeta sin permisos muestra error inline.
  2. Click en archivo Swift → tab con highlighting Palenight + números de línea alineados (scrollear y verificar alineación); copiar código NO incluye los números.
  3. Tabs: re-click en el mismo archivo no duplica; ✕ cierra y selecciona vecino; cerrar el último vuelve a terminal; las tabs de terminal/procesos siguen intactas (scrollback preservado tras pasar por un archivo).
  4. Guardrails: archivo binario → placeholder; archivo enorme (>5MB) → "File too large"; archivo de texto grande (>512KB) → texto plano sin highlight.
  5. Rendimiento: abrir un archivo de ~5k líneas no congela la UI más que un instante.
