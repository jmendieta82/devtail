# Activity bar y panel conmutable (Ciclo 4) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rail de iconos estilo VS Code que conmuta el panel izquierdo entre Archivos y Procesos; el dashboard se muda a la derecha.

**Architecture:** `SidePanelView` (enum) + `WorkspaceSession.sidePanel`; `ActivityBar` (rail 48pt) + `WorkspaceSidePanel` (switch files/procesos, con la sección de procesos extraída de `WorkspaceDashboardColumn`); swap de columnas en `WorkspaceRootView`. El centro no se toca.

**Tech Stack:** Swift 6 / SwiftUI, sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-07-15-activity-bar-design.md`

## Global Constraints

- Branch: `feat/activity-bar` (desde `main` 92b5f21; merge solo tras checkpoint de Javier).
- Suite base actual en main: 0 fallos (conteo ~348; juzgar por exit code/failures; ±1 log artifact conocido). Comando: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet`.
- **PROTOCOLO OOM**: `pgrep -fl xcodebuild || echo clear` → `clear` antes de CUALQUIER build; nunca dos solapados.
- Paths reales `Devtail/Features/...` (NO anidados). Swift 6 MainActor default (sin inits como default params). Retención ZStack del centro intocable. Comentarios/UI strings en inglés; tokens de `DevtailTokens`. Conventional Commits, SIN atribución de AI.

---

### Task 0: Branch

- [ ] `cd /Volumes/Datos/Frelancer/DEVTAIL/Devtail && git checkout main && git checkout -b feat/activity-bar`

---

### Task 1: `SidePanelView` + estado en la sesión

**Files:**
- Create: `Devtail/Features/Workspace/Models/SidePanelView.swift`
- Modify: `Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift` (`WorkspaceSession`)
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift` (extender)

**Interfaces:**
- Produces: `SidePanelView { files, processes }` con `icon`/`help`; `WorkspaceSession.sidePanel: SidePanelView = .files`.

- [ ] **Step 1: Test que falla** (en holder tests, mismo setup vecino):

```swift
@Test func openSessionDefaultsToFilesSidePanel() {
    let session = makeOpenSession()
    #expect(session.sidePanel == .files)
}
```

- [ ] **Step 2: RED focalizado.**
- [ ] **Step 3: Implementar**

`SidePanelView.swift`:

```swift
/// Views the activity-bar rail can show in the workspace side panel.
enum SidePanelView: CaseIterable {
    case files
    case processes

    var icon: String {
        switch self {
        case .files: "folder"
        case .processes: "play.square.stack"
        }
    }

    var help: String {
        switch self {
        case .files: "Files"
        case .processes: "Processes"
        }
    }
}
```

En `WorkspaceSession`: `var sidePanel: SidePanelView = .files`.

- [ ] **Step 4: GREEN + suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 5: Commit** — `git commit -m "feat(workspace): side panel view state with files default"`

---

### Task 2: `ActivityBar` + `WorkspaceSidePanel` (extracción de procesos)

**Files:**
- Create: `Devtail/Features/Workspace/Views/Components/ActivityBar.swift`
- Create: `Devtail/Features/Workspace/Views/Components/WorkspaceSidePanel.swift`
- Modify: `Devtail/Features/Workspace/Views/Components/WorkspaceDashboardColumn.swift` (quitar `processesSection` y sus helpers; conserva header/branch/quick links/sesión)

**Interfaces:**
- Consumes: `SidePanelView` (Task 1), `FileTreeColumn` (existente — el panel `.files` la embebe tal cual), `ProcessCardView` y los closures actuales de `processesSection` (MOVERLOS VERBATIM desde `WorkspaceDashboardColumn`, incluida la semántica onSelect/onStart de las waves 3-4).
- Produces: `ActivityBar(session:)`, `WorkspaceSidePanel(session:)` — los usa Task 3.

- [ ] **Step 1: `ActivityBar.swift`**

```swift
import SwiftUI

/// VS Code-style icon rail: switches what the side panel shows.
struct ActivityBar: View {
    let session: WorkspaceSession

    var body: some View {
        VStack(spacing: DevtailTokens.Spacing.gapSmall) {
            ForEach(SidePanelView.allCases, id: \.self) { view in
                Button {
                    session.sidePanel = view
                } label: {
                    Image(systemName: view.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(session.sidePanel == view
                            ? DevtailTokens.Colors.accentPrimary
                            : DevtailTokens.Colors.textTertiary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help(view.help)
            }
            Spacer()
        }
        .padding(.vertical, DevtailTokens.Spacing.gapSmall)
        .frame(width: 48)
    }
}
```

- [ ] **Step 2: `WorkspaceSidePanel.swift`** — switch + panel de procesos extraído:

```swift
import SwiftUI

/// Side panel content, switched by the activity bar.
struct WorkspaceSidePanel: View {
    let session: WorkspaceSession

    var body: some View {
        switch session.sidePanel {
        case .files:
            FileTreeColumn(session: session)
        case .processes:
            processesPanel
        }
    }

    private var processesPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DevtailTokens.Spacing.gapSmall) {
                SectionHeader(title: "Processes")
                // ForEach + ProcessCardView movidos VERBATIM desde
                // WorkspaceDashboardColumn.processesSection (mismos closures)
            }
            .padding(DevtailTokens.Spacing.cardPadding)
        }
    }
}
```

(El bloque de procesos se copia byte a byte del `processesSection` actual de `WorkspaceDashboardColumn` — incluidos `isSelected`, `onSelect` con guard de sesión, `onStart` que arranca y selecciona, `onStop`, `onRestart` — y después se BORRA de allí junto con helpers que queden huérfanos.)

- [ ] **Step 3: Suite completa** (compila todo; `WorkspaceDashboardColumn` ya sin procesos). Expected: exit 0, 0 failed.
- [ ] **Step 4: Commit** — `git commit -m "feat(workspace): activity bar and switchable side panel"`

---

### Task 3: Swap de columnas en `WorkspaceRootView`

**Files:**
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift`

- [ ] **Step 1: Layout final**

```swift
HSplitView {
    HStack(spacing: 0) {
        ActivityBar(session: session)
        WorkspaceSidePanel(session: session)
    }
    .frame(minWidth: 48 + 220, maxWidth: 48 + 300)

    VStack(spacing: 0) {
        tabRow
        terminalArea
    }
    .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)

    WorkspaceDashboardColumn(session: session)
        .frame(minWidth: 260, maxWidth: 340)
}
```

(Se elimina el uso directo de `FileTreeColumn` como columna derecha — ahora vive dentro del panel. `navigationTitle`/`onDisappear`/centro intactos.)

- [ ] **Step 2: Sweep** — `rg -n "FileTreeColumn" Devtail` → su único uso queda dentro de `WorkspaceSidePanel`.
- [ ] **Step 3: Suite completa.** Expected: exit 0, 0 failed.
- [ ] **Step 4: Commit** — `git commit -m "feat(workspace): rail and panel left, dashboard right"`

---

### Task 4: Ledger, suite final y checkpoint

- [ ] Ledger + suite final (conteo por nombres únicos).
- [ ] **USER CHECKPOINT (Javier)**: rail conmuta Archivos/Procesos con estado visual; procesos operables desde el panel (play abre tab, ✕ cierra); el tree conserva expansión al conmutar ida y vuelta; dashboard a la derecha completo (header, branch, quick links, reloj); centro intacto (tabs efímeras, agente, foco); redimensionar el panel funciona.
