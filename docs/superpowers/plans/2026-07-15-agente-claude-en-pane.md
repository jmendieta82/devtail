# Agente Claude en pane (Ciclo 3) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tab de agente interactiva de primera clase que auto-lanza `claude` (configurable) en el root del proyecto, con pegado de imágenes vía bracketed paste.

**Architecture:** `WorkspaceSession` gana una segunda sesión interactiva (`agent`) espejando la maquinaria del terminal (retención ZStack, identity guard en onExit, restart affordance). `TerminalSessionConfig` gana `imagePaste`; `SwiftTermEngine` monta `AgentTerminalView` (subclase que overridea el `paste(_:)` `open` de SwiftTerm) para inyectar paths de imágenes temp con `insertText(_:isPaste: true)` — el bracketed paste lo aporta SwiftTerm. `AppSettings.agentCommand` (nuevo, UserDefaults) se inyecta por primera vez desde `DevtailApp`.

**Tech Stack:** Swift 6 (MainActor default), SwiftUI + AppKit, SwiftTerm existente (sin SPM nuevos), swift-testing.

**Spec:** `docs/superpowers/specs/2026-07-15-agente-claude-en-pane-design.md`

## Global Constraints

- Branch: `feat/agente-claude-en-pane` (desde `main` e7cc642; merge solo tras checkpoint manual de Javier).
- Suite base: **314 casos, 0 fallos**. Comando: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet` (focalizado: `-only-testing:DevtailTests/<Suite>`).
- **PROTOCOLO OOM**: `pgrep -fl xcodebuild || echo clear` debe dar `clear` antes de CUALQUIER build; nunca dos solapados. Conteos de log ±1 son artefacto conocido — juzgar por exit code y fallos.
- Swift 6 gotcha: init `@MainActor`-aislado NO puede ser default param (incluye structs propios). Inyección explícita siempre.
- La retención ZStack de terminales es intocable (montar siempre, opacity/hitTesting).
- Paths reales: fuentes bajo `Devtail/Features/...` (NO `Devtail/Devtail/...` — incidente Ciclo 2), tests bajo `DevtailTests/Features/...`. Archivos nuevos se auto-incluyen (synchronized groups).
- Código y comentarios en inglés; UI strings en inglés; tokens de `DevtailTokens`. Conventional Commits, SIN atribución de AI.
- No tocar: ProcessSupervisor, FileTree*, CodeViewer*, FileViewerTabView.

---

### Task 0: Branch

- [ ] `cd /Volumes/Datos/Frelancer/DEVTAIL/Devtail && git checkout main && git checkout -b feat/agente-claude-en-pane`

---

### Task 1: `WorkspaceTab.agent` + `AppSettings.agentCommand`

**Files:**
- Modify: `Devtail/Features/Workspace/Models/WorkspaceTab.swift`
- Modify: `Devtail/Core/Settings/AppSettings.swift`
- Test: `DevtailTests/Core/Settings/AppSettingsTests.swift` (extender)

**Interfaces:**
- Produces: `WorkspaceTab.agent`; `AppSettings.agentCommand: String` (default `"claude"`, persiste en `didSet`) — los usan Tasks 2, 4 y 5.

- [ ] **Step 1: Tests que fallan** — en `AppSettingsTests.swift` agregar (mismo patrón `UserDefaults(suiteName:)` de los tests existentes):

```swift
@Test func agentCommandDefaultsToClaude() {
    let settings = AppSettings(defaults: makeDefaults())
    #expect(settings.agentCommand == "claude")
}

@Test func agentCommandReadsStoredValue() {
    let defaults = makeDefaults()
    defaults.set("claude --continue", forKey: "agentCommand")
    #expect(AppSettings(defaults: defaults).agentCommand == "claude --continue")
}

@Test func agentCommandBlankStoredValueFallsBackToClaude() {
    let defaults = makeDefaults()
    defaults.set("   ", forKey: "agentCommand")
    #expect(AppSettings(defaults: defaults).agentCommand == "claude")
}

@Test func agentCommandPersistsOnChange() {
    let defaults = makeDefaults()
    let settings = AppSettings(defaults: defaults)
    settings.agentCommand = "claude --continue"
    #expect(defaults.string(forKey: "agentCommand") == "claude --continue")
}
```

(Si la suite no tiene helper `makeDefaults()`, crearlo local: `UserDefaults(suiteName: "devtail-settings-\(UUID().uuidString)")!` — mismo espíritu que el patrón existente.)

- [ ] **Step 2: RED** (focalizado `AppSettingsTests`). Expected: FAIL de compilación.

- [ ] **Step 3: Implementar**

`WorkspaceTab.swift` — agregar el caso (con doc-comment):

```swift
/// First-class interactive agent tab (auto-launched agent command).
case agent
```

`AppSettings.swift` — guardar la referencia a defaults y agregar la setting:

```swift
private let defaults: UserDefaults

var agentCommand: String {
    didSet { defaults.set(agentCommand, forKey: "agentCommand") }
}
```

En `init(defaults:)`: asignar `self.defaults = defaults`; leer
`let rawCommand = defaults.string(forKey: "agentCommand") ?? ""` y asignar
`self.agentCommand = rawCommand.trimmingCharacters(in: .whitespaces).isEmpty ? "claude" : rawCommand`.
(El `defaultLaunchTarget` existente no se toca.)

- [ ] **Step 4: GREEN focalizado + suite completa.** Expected: exit 0, 0 failed (318).
- [ ] **Step 5: Commit** — `git commit -m "feat(settings): configurable agent command with claude default"`

---

### Task 2: Sesión de agente en `WorkspaceSession` + holder

**Files:**
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift`
- Modify: `Devtail/App/DevtailApp.swift` (instanciar e inyectar `AppSettings`, pasarla al holder)
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift` (extender)

**Interfaces:**
- Consumes: `AppSettings.agentCommand` (Task 1), `TerminalSessionConfig(command:cwd:readOnly:)` existente (el flag `imagePaste` llega en Task 3 — acá spawnear con el config actual y Task 3 lo extiende).
- Produces: `WorkspaceSession.agent: TerminalSession`, `agentExited: Bool`, `WorkspaceSessionsHolder.restartAgent(projectId:)` — los usa Task 4.

- [ ] **Step 1: Tests que fallan** — en `WorkspaceSessionsHolderTests.swift` (el SUT builder gana `settings:`; crear helper con `UserDefaults(suiteName:)` único):

```swift
@Test func openSessionSpawnsAgentWithConfiguredCommand() {
    let (holder, engine) = makeSUT(agentCommand: "claude --continue")
    let session = holder.openSession(for: project())
    let agentConfigs = engine.configs.filter { $0.command == "claude --continue" }
    #expect(agentConfigs.count == 1)
    #expect(agentConfigs[0].readOnly == false)
    #expect(session.agentExited == false)
}

@Test func openSessionSpawnsAgentWithDefaultClaude() {
    let (holder, engine) = makeSUT()
    _ = holder.openSession(for: project())
    #expect(engine.configs.contains { $0.command == "claude" && !$0.readOnly })
}

@Test func agentExitSetsAgentExitedFlag() {
    let (holder, engine) = makeSUT()
    let session = holder.openSession(for: project())
    (session.agent as? MockTerminalSession)?.simulateExit(code: 0)
    #expect(session.agentExited == true)
    #expect(session.interactiveExited == false)
}

@Test func restartAgentCreatesFreshSessionAndResetsFlag() {
    let (holder, engine) = makeSUT()
    let session = holder.openSession(for: project())
    let old = session.agent as? MockTerminalSession
    old?.simulateExit(code: 1)
    holder.restartAgent(projectId: session.projectId)
    #expect(session.agent !== old)
    #expect(session.agentExited == false)
    #expect(old?.terminateCount == 1)
}

@Test func staleAgentExitAfterRestartDoesNotReflipFlag() {
    let (holder, engine) = makeSUT()
    let session = holder.openSession(for: project())
    let old = session.agent as? MockTerminalSession
    holder.restartAgent(projectId: session.projectId)
    old?.simulateExit(code: 1)
    #expect(session.agentExited == false)
}

@Test func closeTerminatesAgentSession() {
    let (holder, engine) = makeSUT()
    let session = holder.openSession(for: project())
    let agent = session.agent as? MockTerminalSession
    holder.close(projectId: session.projectId)
    #expect(agent?.terminateCount == 1)
}
```

Adaptar `makeSUT` para devolver también el engine si ya no lo hace, y aceptar `agentCommand: String? = nil` que setea la key en el `UserDefaults` de test ANTES de crear `AppSettings`. OJO: `WorkspaceSessionOpenFilesTests` también construye el holder en su helper `makeSession()` — actualizar ese helper con el nuevo parámetro `settings:` (un `AppSettings(defaults: UserDefaults(suiteName: ...))` de test). Los tests existentes que cuenten configs interactivos (`!$0.readOnly`) deben actualizarse: ahora hay DOS spawns no-readOnly por sesión (terminal + agente) — ajustar asserts (p.ej. `configs.filter { !$0.readOnly }.count == 2`, y el del terminal identificado por `command == nil`).

- [ ] **Step 2: RED focalizado.**

- [ ] **Step 3: Implementar**

En `WorkspaceSession`: agregar `fileprivate(set) var agent: TerminalSession` y `var agentExited = false` (+ init param `agent: TerminalSession` sin default — inyección explícita, gotcha MainActor).

En `WorkspaceSessionsHolder`:
- init gana `private let settings: AppSettings` (param explícito, sin default).
- `openSession(for:)`: tras crear `interactive`, crear
  `let agent = engine.makeSession(TerminalSessionConfig(command: settings.agentCommand, cwd: root, readOnly: false))`, `agent.start()`, pasar al init de la sesión, y `wireAgentExit(agent, on: session)`.
- `wireAgentExit` espejo exacto de `wireInteractiveExit` (guard `session.agent === terminal` → `session.agentExited = true`).
- `restartAgent(projectId:)` espejo exacto de `restartInteractive` (terminate viejo, makeSession con `settings.agentCommand`, start, reasignar, re-wire, `agentExited = false`).
- `close(projectId:)` y `shutdownAll()`: agregar `session.agent.terminate()` junto al terminate del interactive.

En `DevtailApp.swift`: crear `private let appSettings = AppSettings()` en el bloque de init de stores; pasar `settings: appSettings` al `WorkspaceSessionsHolder(...)`; agregar `.environment(appSettings)` a las escenas dashboard, settings y workspace (junto a los `.environment` existentes).

- [ ] **Step 4: GREEN focalizado + suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 5: Commit** — `git commit -m "feat(workspace): first-class agent session with restart machinery"`

---

### Task 3: `AgentImagePaste` + `AgentTerminalView` + `imagePaste` en el engine

**Files:**
- Create: `Devtail/Features/Workspace/Services/AgentImagePaste.swift`
- Create: `Devtail/Features/Workspace/Views/AgentTerminalView.swift`
- Modify: `Devtail/Features/Workspace/Services/TerminalEngine.swift` (`TerminalSessionConfig` gana `imagePaste`)
- Modify: `Devtail/Features/Workspace/Services/SwiftTermEngine.swift` (selección de vista + cleanup en terminate)
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift` (el spawn del agente pasa `imagePaste: true` — en `openSession` y `restartAgent`)
- Test: `DevtailTests/Features/Workspace/AgentImagePasteTests.swift` (nuevo)

**Interfaces:**
- Consumes: sesión agente (Task 2).
- Produces: `AgentImagePaste.pngData(from: NSPasteboard) -> Data?`, `AgentImagePaste.saveTempImage(_ data: Data, in dir: URL) -> URL?`, `AgentImagePaste.makeTempDir() -> URL`, `AgentImagePaste.cleanup(dir: URL)`; `AgentTerminalView`; `TerminalSessionConfig.imagePaste`.

- [ ] **Step 1: Tests que fallan** — `AgentImagePasteTests.swift`:

```swift
import AppKit
import Testing
@testable import Devtail

@MainActor
struct AgentImagePasteTests {
    private func makePasteboard() -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("devtail-test-\(UUID().uuidString)"))
        pb.clearContents()
        return pb
    }

    private func tinyPNG() -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func extractsPNGFromBitmapPasteboard() {
        let pb = makePasteboard()
        pb.setData(tinyPNG(), forType: .png)
        #expect(AgentImagePaste.pngData(from: pb) != nil)
    }

    @Test func extractsPNGFromTIFFPasteboard() {
        let pb = makePasteboard()
        let image = NSImage(data: tinyPNG())!
        pb.setData(image.tiffRepresentation!, forType: .tiff)
        #expect(AgentImagePaste.pngData(from: pb) != nil)
    }

    @Test func extractsPNGFromImageFileURL() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-imgtest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("shot.png")
        try tinyPNG().write(to: file)
        let pb = makePasteboard()
        pb.writeObjects([file as NSURL])
        #expect(AgentImagePaste.pngData(from: pb) != nil)
    }

    @Test func textOnlyPasteboardYieldsNil() {
        let pb = makePasteboard()
        pb.setString("hola", forType: .string)
        #expect(AgentImagePaste.pngData(from: pb) == nil)
    }

    @Test func nonImageFileURLYieldsNil() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-imgtest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("notes.txt")
        try Data("x".utf8).write(to: file)
        let pb = makePasteboard()
        pb.writeObjects([file as NSURL])
        #expect(AgentImagePaste.pngData(from: pb) == nil)
    }

    @Test func saveAndCleanupTempImages() {
        let dir = AgentImagePaste.makeTempDir()
        let url = AgentImagePaste.saveTempImage(tinyPNG(), in: dir)
        #expect(url != nil)
        #expect(FileManager.default.fileExists(atPath: url!.path))
        #expect(url!.pathExtension == "png")
        AgentImagePaste.cleanup(dir: dir)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }
}
```

- [ ] **Step 2: RED focalizado.**

- [ ] **Step 3: Implementar**

`AgentImagePaste.swift`:

```swift
import AppKit

/// Pasteboard → temp PNG plumbing for the agent tab's image paste.
enum AgentImagePaste {
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"]

    /// PNG data from the pasteboard: direct bitmap (png/tiff) or an image file URL.
    static func pngData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) { return png }
        if let tiff = pasteboard.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff) {
            return rep.representation(using: .png, properties: [:])
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let imageURL = urls.first(where: { imageExtensions.contains($0.pathExtension.lowercased()) }),
           let data = try? Data(contentsOf: imageURL),
           let rep = NSBitmapImageRep(data: data) {
            return rep.representation(using: .png, properties: [:])
        }
        return nil
    }

    static func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtail-agent-images-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func saveTempImage(_ data: Data, in dir: URL) -> URL? {
        let url = dir.appendingPathComponent("image-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    static func cleanup(dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }
}
```

`AgentTerminalView.swift`:

```swift
import AppKit
import SwiftTerm

/// Interactive terminal for the agent tab. Overrides paste so images land as
/// bracketed-pasted temp-file paths (the agent TUI renders them as [Image #N]);
/// plain text falls through to SwiftTerm's normal paste.
final class AgentTerminalView: LocalProcessTerminalView {
    let imageDir = AgentImagePaste.makeTempDir()

    override func paste(_ sender: Any) {
        if let png = AgentImagePaste.pngData(from: NSPasteboard.general),
           let url = AgentImagePaste.saveTempImage(png, in: imageDir) {
            // Hand-rolled bracketed-paste wrap: the insertText(...isPaste:)
            // overload is internal to SwiftTerm. Mirrors its non-kitty paste
            // path; degrades to an unwrapped path when mode 2004 is off.
            let bracketed = getTerminal().bracketedPasteMode
            if bracketed { send(data: EscapeSequences.bracketedPasteStart[0...]) }
            send(txt: url.path)
            if bracketed { send(data: EscapeSequences.bracketedPasteEnd[0...]) }
            return
        }
        super.paste(sender)
    }

    func cleanupImages() {
        AgentImagePaste.cleanup(dir: imageDir)
    }
}
```

`TerminalEngine.swift` — `TerminalSessionConfig` gana `let imagePaste: Bool` con default `false` (default de Bool literal, sin gotcha MainActor):

```swift
init(command: String?, cwd: URL, readOnly: Bool, imagePaste: Bool = false) { ... }
```

`SwiftTermEngine.swift` — selección de vista en `SwiftTermSession.init`:

```swift
if config.readOnly {
    self.terminalView = ReadOnlyLocalProcessTerminalView(frame: .zero)
} else if config.imagePaste {
    self.terminalView = AgentTerminalView(frame: .zero)
} else {
    self.terminalView = LocalProcessTerminalView(frame: .zero)
}
```

y en `terminate()`: `(terminalView as? AgentTerminalView)?.cleanupImages()` antes del kill.

`WorkspaceSessionsHolder`: los dos spawns del agente (openSession y restartAgent) pasan `imagePaste: true`.

- [ ] **Step 4: GREEN focalizado + suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 5: Commit** — `git commit -m "feat(agent): image paste as bracketed temp-file paths"`

---

### Task 4: UI — tab de agente + overlay de restart

**Files:**
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift`

**Interfaces:**
- Consumes: `session.agent`, `session.agentExited`, `holder.restartAgent(projectId:)` (Task 2), `WorkspaceTab.agent` (Task 1).

- [ ] **Step 1: tabRow** — tras el botón terminal: `tabButton(title: "agent", tab: .agent)`.

- [ ] **Step 2: terminalArea** — dentro del ZStack, junto al interactive (misma disciplina: montado SIEMPRE):

```swift
TerminalHostView(terminalView: session.agent.view)
    .opacity(session.selectedTab == .agent ? 1 : 0)
    .allowsHitTesting(session.selectedTab == .agent)
```

y el overlay espejo del deadShellOverlay:

```swift
if session.selectedTab == .agent && session.agentExited {
    deadAgentOverlay
}
```

`deadAgentOverlay`: copiar la estructura exacta de `deadShellOverlay` cambiando el texto a "agent exited" y el botón a `Button("Restart agent") { holder.restartAgent(projectId: session.projectId) }`.

- [ ] **Step 3: Suite completa** (view-only). Expected: exit 0, 0 failed.
- [ ] **Step 4: Commit** — `git commit -m "feat(workspace): first-class agent tab with restart affordance"`

---

### Task 5: Muere el toggle + Settings real

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Views/ProjectFormView.swift` (quitar `claudeCodeToggle` y su `@State`)
- Modify: `Devtail/Features/ContextSwitcher/Stores/ProjectStore.swift` (`createProject` pierde `runClaudeCode`; el seed del root pane queda con `command: ""`)
- Create: `Devtail/Core/Settings/SettingsView.swift`
- Modify: `Devtail/App/DevtailApp.swift` (Settings window usa `SettingsView` en vez de `ComingSoonView`)
- Test: actualizar tests de `createProject` que pasen/asserten `runClaudeCode` (`rg -n "runClaudeCode" DevtailTests Devtail`)

**Interfaces:**
- Consumes: `AppSettings` inyectado (Task 2).

- [ ] **Step 1: Quitar `runClaudeCode`** — de la firma de `createProject` (el seed queda `command: ""` incondicional), del form (toggle + estado + call site), y de todo test que lo use (`createProjectWithDirectoryPathSeedsRootPane` asserta el seed: ajustar a `command == ""`). RED→GREEN focalizado en `ProjectStoreTests`.

- [ ] **Step 2: `SettingsView`**:

```swift
import SwiftUI

/// Real settings pane (replaces the ComingSoon placeholder).
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Agent") {
                TextField("Agent command", text: $settings.agentCommand)
                    .font(DevtailTokens.Typography.mono)
                Text("Launched in the agent tab when a workspace opens. Example: claude --continue")
                    .font(.caption)
                    .foregroundStyle(DevtailTokens.Colors.textTertiary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }
}
```

En `DevtailApp`: `Window("Settings", ...) { SettingsView() }` (mantener `.environment(appSettings)` de Task 2; conservar tamaño/resizability existentes).

Nota semántica: `agentCommand` persiste en cada `didSet` (cada keystroke). Aceptado — es un solo campo; el valor rige en el PRÓXIMO spawn de agente (documentarlo en el caption si hace falta).

- [ ] **Step 3: Suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 4: Commit** — `git commit -m "feat(settings): agent command UI, retire run-claude-code toggle"`

---

### Task 6: Ledger, suite final y checkpoint manual

- [ ] **Step 1**: Append al ledger (`.superpowers/sdd/progress.md`, git-ignored) la sección del Ciclo 3 con estado por task.
- [ ] **Step 2**: Suite completa final; registrar conteo por nombres únicos.
- [ ] **Step 3: USER CHECKPOINT (Javier) — bloquea merge**:
  1. Abrir un workspace → la tab "agent" existe y Claude arrancó solo en el root del proyecto (PATH ok).
  2. Escribir en la tab agent → responde (interactivo pleno, a diferencia del pane read-only).
  3. Cmd+V con una captura de pantalla en el clipboard → aparece `[Image #N]` en el input de Claude y el agente puede leer la imagen.
  4. Cmd+V con texto normal → pega texto normal.
  5. Salir de claude (`/exit` o Ctrl+C hasta salir) → overlay "agent exited" con Restart agent → restart funciona.
  6. Settings → cambiar Agent command a `claude --continue`, cerrar y reabrir el workspace → el agente retoma la conversación.
  7. terminal/procesos/archivos intactos (scrollback al pasar por agent y volver).
  8. Crear un proyecto nuevo → ya no existe el toggle de Claude Code y el agente aparece igual.
  9. Cerrar la ventana → `lsof` sin huérfanos (el proceso del agente muere con la ventana).
