# Settings en el workspace — Implementation Plan (Ciclo 5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configuración del proyecto integrada en el workspace (engranaje en el rail → tab efímera con el form), retiro de los entry points de edición del hub y del picker LAYOUT, con reflejo en vivo de los procesos vía `ProcessSupervisor.reconfigure`.

**Architecture:** Se reutiliza `ProjectFormView` en modo edición dentro de una tab efímera nueva (`WorkspaceTab.settings`) montada en el ZStack central. El supervisor gana `reconfigure(panes:root:)` con diff por `pane.id` (los `ManagedProcess` conservados sobreviven con su sesión). El hub pierde la edición y conserva create+launch.

**Tech Stack:** Swift 6 (MainActor default), SwiftUI, SwiftData, Swift Testing (`@Test`/`#expect`), tokens `DevtailTokens`.

**Spec:** `docs/superpowers/specs/2026-07-16-settings-en-workspace-design.md`

## Global Constraints

- Código/comentarios/UI en inglés; conventional commits sin atribución de IA.
- Los procesos NO auto-arrancan nunca (directiva de Javier).
- Protocolo OOM: un solo runner de xcodebuild, `pgrep -f xcodebuild` antes de cada corrida, `-jobs 4`.
- `Project.layout` y `WorkspacePane.layoutSlot` quedan INTACTOS en el modelo (dormidos) — solo se retira UI y el método de store sin callers.
- Los planes citan líneas de referencia; ante drift, manda el contenido real del archivo. Deviaciones se anotan en el reporte del task.
- Suite base al arrancar: 357 casos únicos / 0 fallos sobre `22cb12b`.

---

### Task 1: `ProcessSupervisor.reconfigure` + `ManagedProcess` mutable (TDD)

**Files:**
- Modify: `Devtail/Features/Workspace/Models/ManagedProcess.swift` (campos `let` → `private(set) var`, método `apply`)
- Modify: `Devtail/Features/Workspace/Services/ProcessSupervisor.swift` (nuevo `reconfigure(panes:root:)`)
- Test: `DevtailTests/Features/Workspace/ProcessSupervisorReconfigureTests.swift` (nuevo)

**Interfaces:**
- Consumes: `ManagedProcess(pane:root:)`, `ProcessSupervisor.configure/start/stop/close`, `MockTerminalEngine` (patrones de `ProcessSupervisorTests`).
- Produces: `func reconfigure(panes: [WorkspacePane], root: URL)` en `ProcessSupervisor`; `func apply(pane: WorkspacePane, root: URL)` en `ManagedProcess`. Task 2 llama `session.supervisor.reconfigure(panes:root:)`.

- [ ] **Step 1: Failing tests.** Crear `ProcessSupervisorReconfigureTests.swift` siguiendo el estilo de `ProcessSupervisorTests` (mismo setup de `MockTerminalEngine`/`MockBrowserLauncher`; adaptar helpers reales):

```swift
import Foundation
import Testing
@testable import Devtail

@MainActor
struct ProcessSupervisorReconfigureTests {
    private func makeSupervisor() -> (ProcessSupervisor, MockTerminalEngine) {
        let engine = MockTerminalEngine()
        return (ProcessSupervisor(engine: engine, browserLauncher: MockBrowserLauncher()), engine)
    }
    private let root = URL(fileURLWithPath: "/tmp/reconf")

    @Test func survivingRunningPaneKeepsItsSessionAndState() {
        let (supervisor, _) = makeSupervisor()
        let pane = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                                 order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [pane], root: root)
        supervisor.start(supervisor.processes[0])
        let session = supervisor.processes[0].session
        #expect(supervisor.processes[0].state == .running)

        supervisor.reconfigure(panes: [pane], root: root)

        #expect(supervisor.processes.count == 1)
        #expect(supervisor.processes[0].session === session)
        #expect(supervisor.processes[0].state == .running)
    }

    @Test func removedPaneIsClosedAndDisappears() {
        let (supervisor, _) = makeSupervisor()
        let keep = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                                 order: 0, layoutSlot: 0, project: nil)
        let drop = WorkspacePane(label: "web", relativeCwd: "web", command: "ng serve",
                                 order: 1, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [keep, drop], root: root)
        supervisor.start(supervisor.processes[1])

        supervisor.reconfigure(panes: [keep], root: root)

        #expect(supervisor.processes.map(\.name) == ["api"])
        // La sesión del removido fue terminada (verificar vía MockTerminalEngine,
        // mismo mecanismo que usan los tests de close existentes).
    }

    @Test func newPaneAppearsStoppedAndNotStarted() {
        let (supervisor, _) = makeSupervisor()
        let a = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                              order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [a], root: root)
        let b = WorkspacePane(label: "web", relativeCwd: "web", command: "ng serve",
                              order: 1, layoutSlot: 0, project: nil)

        supervisor.reconfigure(panes: [a, b], root: root)

        #expect(supervisor.processes.map(\.name) == ["api", "web"])
        #expect(supervisor.processes[1].state == .stopped)
        #expect(supervisor.processes[1].session == nil)
    }

    @Test func changedCommandOnRunningProcessAppliesOnNextStart() {
        let (supervisor, engine) = makeSupervisor()
        let pane = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                                 order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [pane], root: root)
        supervisor.start(supervisor.processes[0])
        pane.command = "npm run dev"

        supervisor.reconfigure(panes: [pane], root: root)
        #expect(supervisor.processes[0].state == .running) // no lo mata

        supervisor.restart(supervisor.processes[0])
        // El último spawn del engine usó "npm run dev" (adaptar a cómo
        // MockTerminalEngine registra comandos en los tests existentes).
    }

    @Test func blankCommandPanesAreFilteredOut() {
        let (supervisor, _) = makeSupervisor()
        let a = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                              order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [a], root: root)
        let blank = WorkspacePane(label: "todo", relativeCwd: ".", command: "  ",
                                  order: 1, layoutSlot: 0, project: nil)

        supervisor.reconfigure(panes: [a, blank], root: root)

        #expect(supervisor.processes.map(\.name) == ["api"])
    }

    @Test func reconfigureRespectsPaneOrder() {
        let (supervisor, _) = makeSupervisor()
        let a = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                              order: 5, layoutSlot: 0, project: nil)
        let b = WorkspacePane(label: "web", relativeCwd: "web", command: "ng serve",
                              order: 1, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [a], root: root)

        supervisor.reconfigure(panes: [a, b], root: root)

        #expect(supervisor.processes.map(\.name) == ["web", "api"])
    }

    @Test func renamedPaneUpdatesCardName() {
        let (supervisor, _) = makeSupervisor()
        let pane = WorkspacePane(label: "api", relativeCwd: "api", command: "npm start",
                                 order: 0, layoutSlot: 0, project: nil)
        supervisor.configure(panes: [pane], root: root)
        pane.label = "backend"

        supervisor.reconfigure(panes: [pane], root: root)

        #expect(supervisor.processes[0].name == "backend")
    }
}
```

- [ ] **Step 2: Correr y verificar que fallan** (no existe `reconfigure`): `pgrep -f xcodebuild` antes; `xcodebuild test ... -only-testing:DevtailTests/ProcessSupervisorReconfigureTests -jobs 4 -quiet`. Expected: compile error → escribir stub vacío que compile y verificar FAIL de asserts.

- [ ] **Step 3: Implementación.** En `ManagedProcess.swift`: pasar `name`, `command`, `cwd`, `isFrontend`, `localhostUrl` de `let` a `private(set) var`; extraer el cálculo de cwd del init a un helper estático y agregar:

```swift
/// Refreshes the pane-derived fields after a settings edit. The live
/// session (if any) keeps running its already-spawned command; the new
/// command takes effect on the next start/restart.
func apply(pane: WorkspacePane, root: URL) {
    name = pane.label
    command = pane.command
    cwd = Self.resolveCwd(relativeCwd: pane.relativeCwd, root: root)
    isFrontend = pane.isFrontend
    localhostUrl = pane.localhostUrl
}
```

En `ProcessSupervisor.swift` (mismo filtro/orden que `configure` — extraer helper compartido si queda DRY):

```swift
/// Incremental re-sync after a settings edit: surviving panes keep their
/// ManagedProcess (and live session) by pane id, removed panes are closed,
/// new panes appear as stopped cards. Never auto-starts anything.
func reconfigure(panes: [WorkspacePane], root: URL) {
    let incoming = panes
        .filter { !$0.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .sorted { $0.order < $1.order }
    let incomingIds = Set(incoming.map(\.id))

    for process in processes where !incomingIds.contains(process.id) {
        close(process)
    }

    let existing = Dictionary(uniqueKeysWithValues: processes.map { ($0.id, $0) })
    processes = incoming.map { pane in
        if let current = existing[pane.id] {
            current.apply(pane: pane, root: root)
            return current
        }
        return ManagedProcess(pane: pane, root: root)
    }
}
```

- [ ] **Step 4: Verde focalizado + suite de supervisor completa** (`-only-testing:DevtailTests/ProcessSupervisorReconfigureTests -only-testing:DevtailTests/ProcessSupervisorTests`). Expected: PASS todo.
- [ ] **Step 5: Commit** `feat(workspace): incremental supervisor reconfigure preserving live sessions`

---

### Task 2: `WorkspaceTab.settings` — rail, chip y tab con el form

**Files:**
- Modify: `Devtail/Features/Workspace/Models/WorkspaceTab.swift` (caso `.settings`)
- Modify: `Devtail/Features/Workspace/Views/Components/ActivityBar.swift` (engranaje al fondo)
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift` (chip + mount en ZStack)
- Create: `Devtail/Features/Workspace/Views/Components/WorkspaceSettingsTabView.swift`
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift` (agregar caso de fallback si hay hueco razonable; la tab settings es mayormente wiring de vista)

**Interfaces:**
- Consumes: `reconfigure(panes:root:)` del Task 1; `WorkspaceTabChip` existente; `ProjectFormView(projectID:onDismiss:isDirty:)`; `session.root`, `session.projectId`, `session.supervisor`; environment `ProjectStore` (ya inyectado en la escena Workspace, `DevtailApp.swift:94-110`).
- Produces: caso `WorkspaceTab.settings`; vista `WorkspaceSettingsTabView(session:)`.

- [ ] **Step 1:** Agregar caso a `WorkspaceTab.swift`:

```swift
/// Project settings form, rendered as an ephemeral center tab.
case settings
```

- [ ] **Step 2:** `ActivityBar.swift` — después del `Spacer()` existente (línea ~23), botón engranaje con el MISMO estilo visual de los items (frame 32×32, `.plain`, `.help`):

```swift
Button {
    session.selectedTab = .settings
} label: {
    Image(systemName: "gearshape")
        .font(.system(size: 16))
        .foregroundStyle(session.selectedTab == .settings
            ? DevtailTokens.Colors.accentPrimary
            : DevtailTokens.Colors.textTertiary)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
.help("Project settings")
```

(Adaptar tamaño de icono al que usen los items reales del rail.)

- [ ] **Step 3:** `WorkspaceRootView.tabRow` — chip settings al final del HStack, visible solo mientras está seleccionada (espejo del file viewer: nada que preservar al cerrar):

```swift
if session.selectedTab == .settings {
    WorkspaceTabChip(
        icon: "gearshape",
        title: "settings",
        isSelected: true,
        select: {},
        close: { session.selectedTab = .agent }
    )
}
```

Y en `terminalArea` (junto al mount condicional del file viewer):

```swift
if session.selectedTab == .settings {
    WorkspaceSettingsTabView(session: session)
}
```

- [ ] **Step 4:** Crear `WorkspaceSettingsTabView.swift`:

```swift
//
//  WorkspaceSettingsTabView.swift
//  Devtail
//
//  Project settings as an ephemeral center tab: reuses ProjectFormView in
//  edit mode. Pane edits save straight through the store, so this view
//  watches the panes signature and re-syncs the supervisor incrementally —
//  the open workspace reflects process changes without relaunching.
//

import SwiftUI

struct WorkspaceSettingsTabView: View {
    @Environment(ProjectStore.self) private var store
    let session: WorkspaceSession
    @State private var isDirty = false

    private var project: Project? {
        store.projects.first { $0.id == session.projectId }
    }

    var body: some View {
        Group {
            if let project {
                ProjectFormView(
                    projectID: project.id,
                    onDismiss: { session.selectedTab = .agent },
                    isDirty: $isDirty
                )
                .onChange(of: panesSignature(of: project)) {
                    session.supervisor.reconfigure(
                        panes: project.workspacePanes.sorted { $0.order < $1.order },
                        root: session.root
                    )
                }
            } else {
                Text("project not found")
                    .font(DevtailTokens.Typography.caption)
                    .foregroundStyle(DevtailTokens.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DevtailTokens.Colors.appBackground)
    }

    /// Cheap change signature over everything the supervisor cares about.
    private func panesSignature(of project: Project) -> [String] {
        project.workspacePanes
            .sorted { $0.order < $1.order }
            .map { "\($0.id)|\($0.label)|\($0.command)|\($0.relativeCwd)|\($0.isFrontend)|\($0.localhostUrl ?? "")" }
    }
}
```

(Verificar cómo se presenta `ProjectFormView` en `DashboardRootView` — si allí va dentro de scroll propio, replicar; si no, envolver en `ScrollView`.)

- [ ] **Step 5: Suite focalizada de workspace** (`WorkspaceSessionsHolderTests`, `WorkspaceSessionOpenFilesTests`, `ProcessSupervisor*`). Expected: PASS.
- [ ] **Step 6: Commit** `feat(workspace): project settings as ephemeral center tab from the rail`

---

### Task 3: Retiro del picker LAYOUT

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Views/ProjectFormView.swift` (borrar `layoutSection` líneas ~186-195 y su render en el bloque edit, línea ~47)
- Delete: la vista `WorkspaceLayoutPicker` (localizar con `rg -l "WorkspaceLayoutPicker" Devtail/`)
- Modify: `Devtail/Features/ContextSwitcher/Stores/ProjectStore.swift` (borrar `setLayout(for:layout:)`, líneas ~387-393)
- Test: borrar solo los tests DIRECTOS de `setLayout`/picker (localizar con `rg -l "setLayout" DevtailTests/`); los tests del MODELO `Project.layout`/`layoutSlot` quedan intactos (campos dormidos)

**Interfaces:**
- Consumes: nada de tasks previos (independiente).
- Produces: form sin LAYOUT en ambos modos. `Project.layout` y `WorkspacePane.layoutSlot` siguen existiendo — NADIE los toca desde UI.

- [ ] **Step 1:** Borrar render + sección en `ProjectFormView`; borrar el archivo de `WorkspaceLayoutPicker`; borrar `ProjectStore.setLayout`.
- [ ] **Step 2:** Sweep de huérfanos: `rg -n "WorkspaceLayoutPicker|setLayout" Devtail/ DevtailTests/` → solo deben quedar hits del modelo (`Project.layout`, `layoutSlot`) y sus tests de modelo. Ajustar tests directos de setLayout que fallen.
- [ ] **Step 3:** Suite de ContextSwitcher (`-only-testing:DevtailTests` focalizado a `ProjectStoreTests`, `WorkspaceLayoutTests`, `ProjectFormView` no tiene tests de UI). Expected: PASS (menos los borrados).
- [ ] **Step 4: Commit** `feat(hub): retire the layout picker (model stays dormant)`

---

### Task 4: Hub sin edición — create + launch únicamente

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Views/Components/DashboardDetailView.swift` (quitar "Edit project" del menú, línea ~326, y el parámetro `onEditProject`)
- Modify: `Devtail/Features/ContextSwitcher/Views/DashboardRootView.swift` (quitar `DashboardMode.editingProject` + `startEditing` + rama `.editProject` de `consumePendingIntent` + wiring `onEditProject` línea ~327; el render `.editingProject` líneas ~310-318)
- Modify: `Devtail/Features/ContextSwitcher/Views/MenuBarRootView.swift` (líneas ~250-254: `openDashboardForProject` pasa de intent `.editProject` a `.showProject` — abre el dashboard con el proyecto seleccionado en browsing)
- Modify: donde viva `DashboardIntent` (localizar con `rg -n "enum DashboardIntent" Devtail/`): renombrar caso `editProject(UUID)` → `showProject(UUID)`
- Test: actualizar tests que referencien `editProject`/`startEditing` (localizar con `rg -l "editProject|editingProject" DevtailTests/`)

**Interfaces:**
- Consumes: nada de tasks previos (independiente; idealmente después del Task 2 para que la edición nueva ya exista antes de retirar la vieja).
- Produces: hub sin ruta de edición; `DashboardIntent.showProject(UUID)` selecciona el proyecto en modo `.browsing`.

- [ ] **Step 1:** Renombrar el intent y reescribir `consumePendingIntent`: `.showProject(id)` → setear la selección del sidebar (usar la var de selección existente de `DashboardRootView`; verificar su nombre real) y `mode = .browsing`.
- [ ] **Step 2:** Quitar `DashboardMode.editingProject`, `startEditing`, el render branch y el botón/parámetro `onEditProject` end-to-end. Sweep: `rg -n "editingProject|startEditing|onEditProject|editProject" Devtail/` → cero hits.
- [ ] **Step 3:** Actualizar tests afectados; correr suite focalizada de ContextSwitcher. Expected: PASS.
- [ ] **Step 4: Commit** `feat(hub): retire edit entry points, hub is create and launch only`

---

### Task 5: Suite final + ledger

- [ ] **Step 1:** `pgrep -f xcodebuild`; suite completa `-jobs 4`. Expected: 0 fallos; anotar conteo único de casos.
- [ ] **Step 2:** Actualizar `.superpowers/sdd/progress.md` con la sección del Ciclo 5 (tasks, commits, conteos, deviaciones) — el ledger está gitignoreado, no se commitea.
- [ ] **Step 3:** Review final de branch (una lens dominante o 4R si el diff supera 400 líneas autoradas) + fix wave si aplica.
- [ ] **Step 4:** `>>> PENDIENTE: USER CHECKPOINT (Javier)` — bloquea merge a main. Guía de checkpoint: engranaje abre settings, editar proceso se refleja en cards sin relanzar, borrar/agregar proceso, LAYOUT ausente, hub sin Edit, New Project intacto.
