# Workspace de tres columnas y hub delgado (Ciclo 1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reestructurar la ventana de workspace a tres columnas (dashboard | terminal | placeholder del file tree), mover la edición de procesos/quick links/layout a `ProjectFormView`, y adelgazar `DashboardDetailView` a un welcome estilo JetBrains.

**Architecture:** El `HSplitView` de `WorkspaceRootView` pasa de 2 a 3 paneles; el contenido del sidebar derecho actual se muda a una nueva `WorkspaceDashboardColumn` a la izquierda (cards: header, git, procesos, quick links, sesión). La edición que hoy vive en el detail del hub (panes vía `WorkspacePaneEditRow`, quick links vía `QuickLinksPanel`, layout vía `WorkspaceLayoutPicker`) se muda a `ProjectFormView` en modo edición ANTES de borrarla del hub — nunca hay un commit donde la edición no exista en ningún lado. Sin cambios de semántica en `WorkspaceSessionsHolder` ni migración de SwiftData.

**Tech Stack:** Swift 6 (MainActor default isolation), SwiftUI, swift-testing (`import Testing`), SwiftData intacto. Sin dependencias SPM nuevas.

**Spec:** `docs/superpowers/specs/2026-07-15-workspace-tres-columnas-design.md`

## Global Constraints

- Branch de trabajo: `feat/workspace-tres-columnas` (crear desde `main` al inicio; commits ahí, merge solo tras checkpoint manual de Javier).
- Suite base: **283 tests verdes** en `main`. Ningún task puede dejar la suite roja al commitear.
- Comando de test: `xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet`. Focalizado: añadir `-only-testing:DevtailTests/<SuiteName>`.
- **PROTOCOLO OOM (obligatorio)**: antes de CUALQUIER `xcodebuild`, verificar que no hay otro corriendo: `pgrep -fl xcodebuild || echo clear` debe imprimir `clear`. NUNCA dos builds solapados (incidente real de 44GB documentado en `.superpowers/sdd/progress.md`).
- Swift 6 gotcha (ya mordió DOS veces): un `init()` aislado a `@MainActor` NO puede usarse como valor por defecto de parámetro. `Date()` sí puede (es nonisolated).
- UI strings en inglés hardcodeado (convención del proyecto: no hay catálogo de localización).
- Commits: Conventional Commits, SIN "Co-Authored-By" ni atribución de AI.
- Tokens visuales: usar `DevtailTokens` (`Colors.accentPrimary`, `Radius.card = 8`, `Spacing.cardPadding = 14`, etc.) y componentes existentes (`SectionHeader`, `ActivityDot`). Al MOVER vistas, copiar los modificadores exactos del código original — no reinventar estilos.
- Las columnas dormidas de SwiftData (`layoutSlot`, `layout`, `launchTarget`) siguen dormidas: no se agregan ni borran columnas de modelos `@Model`.

---

### Task 0: Branch

- [ ] **Step 1: Crear el branch**

```bash
cd /Volumes/Datos/Frelancer/DEVTAIL/Devtail
git checkout main && git pull && git checkout -b feat/workspace-tres-columnas
```

---

### Task 1: `WorkspaceSession.openedAt` + `WorkspaceSessionClock`

La card "Session" de la columna dashboard necesita saber cuándo se abrió el workspace. Hoy `WorkspaceSession` no tiene timestamp (verificado por grep). Se agrega `openedAt` y un formateador puro testeable.

**Files:**
- Create: `Devtail/Devtail/Features/Workspace/Models/WorkspaceSessionClock.swift`
- Modify: `Devtail/Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift` (clase `WorkspaceSession`, ~L13-48)
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionClockTests.swift` (nuevo)
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift` (extender)

**Interfaces:**
- Consumes: nada nuevo.
- Produces: `WorkspaceSessionClock.elapsedLabel(from: Date, to: Date) -> String` y `WorkspaceSession.openedAt: Date` — los usa la Task 2.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `DevtailTests/Features/Workspace/WorkspaceSessionClockTests.swift`:

```swift
import Foundation
import Testing
@testable import Devtail

struct WorkspaceSessionClockTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func underOneMinuteShowsLessThanOne() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(59)) == "<1m")
    }

    @Test func minutesOnly() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(12 * 60)) == "12m")
    }

    @Test func hoursAndMinutesPadded() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(3_600 + 5 * 60)) == "1h 05m")
    }

    @Test func manyHoursDoNotRollOverToDays() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(26 * 3_600 + 10 * 60)) == "26h 10m")
    }

    @Test func futureStartClampsToZero() {
        #expect(WorkspaceSessionClock.elapsedLabel(from: start, to: start.addingTimeInterval(-30)) == "<1m")
    }
}
```

En `WorkspaceSessionsHolderTests.swift`, agregar dentro de la suite existente (usar el mismo patrón de setup que los tests vecinos para crear una sesión):

```swift
@Test func openSessionStampsOpenedAt() {
    // usar el mismo helper/arranque que los tests existentes de openSession
    // (holder con MockTerminalEngine y un Project de prueba)
    let session = holder.openSession(for: project)
    #expect(abs(session.openedAt.timeIntervalSinceNow) < 5)
}
```

- [ ] **Step 2: Verificar que fallan**

```bash
pgrep -fl xcodebuild || echo clear
xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet -only-testing:DevtailTests/WorkspaceSessionClockTests
```
Expected: FAIL — `cannot find 'WorkspaceSessionClock' in scope`.

- [ ] **Step 3: Implementación mínima**

Crear `Devtail/Devtail/Features/Workspace/Models/WorkspaceSessionClock.swift`:

```swift
import Foundation

/// Pure formatter for the workspace session clock card.
enum WorkspaceSessionClock {
    static func elapsedLabel(from start: Date, to now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(start))) / 60
        if minutes < 1 { return "<1m" }
        if minutes < 60 { return "\(minutes)m" }
        return String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
}
```

En `WorkspaceSession` (dentro de `WorkspaceSessionsHolder.swift`): agregar la propiedad y el parámetro de init con default (seguro: `Date()` es nonisolated):

```swift
let openedAt: Date
```

y en el `init`, agregar `openedAt: Date = Date()` al final de la lista de parámetros con default, asignando `self.openedAt = openedAt`.

- [ ] **Step 4: Verificar que pasan (focalizado + holder)**

```bash
pgrep -fl xcodebuild || echo clear
xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet -only-testing:DevtailTests/WorkspaceSessionClockTests -only-testing:DevtailTests/WorkspaceSessionsHolderTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Devtail/Features/Workspace/Models/WorkspaceSessionClock.swift Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift DevtailTests/Features/Workspace/WorkspaceSessionClockTests.swift DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift
git commit -m "feat(workspace): session open timestamp and elapsed-time formatter"
```

Nota: si Xcode no materializa el archivo nuevo en el target automáticamente (proyecto pbxproj clásico), agregar `WorkspaceSessionClock.swift` al target `Devtail` y el test al target `DevtailTests` editando `Devtail.xcodeproj/project.pbxproj` con el mismo patrón de entradas que los archivos hermanos (así se hizo en v1 con SwiftTerm — ver progress.md Task 2).

---

### Task 2: `WorkspaceDashboardColumn` (columna izquierda)

Nueva vista que absorbe el contenido del `sidebar` actual de `WorkspaceRootView` (L97-130) y agrega header de proyecto, quick links vivos y card de sesión. En este task la vista se crea y se usa REEMPLAZANDO al sidebar derecho actual (el layout de 3 columnas llega en Task 3 — acá solo cambia el contenido del panel derecho existente para mantener la app compilando y usable en cada commit).

**Files:**
- Create: `Devtail/Devtail/Features/Workspace/Views/Components/WorkspaceDashboardColumn.swift`
- Modify: `Devtail/Devtail/Features/Workspace/Views/WorkspaceRootView.swift` (reemplazar la property `sidebar` por la nueva vista; borrar `sidebar`)
- Modify: `Devtail/Devtail/Features/Workspace/Stores/WorkspaceSessionsHolder.swift` (eliminar el snapshot `quickLinks` de `WorkspaceSession`, ver Step 3)
- Test: `DevtailTests/Features/Workspace/WorkspaceSessionsHolderTests.swift` (ajustar tests del snapshot)

**Interfaces:**
- Consumes: `WorkspaceSession` (con `openedAt` de Task 1), `ProcessCardView(process:isSelected:onSelect:onStart:onStop:onRestart:)`, `QuickLinksPanel(projectID:isReadOnly:hideTitle:)`, `SectionHeader(title:)`, `ActivityDot(isActive:)`, `WorkspaceSessionClock.elapsedLabel(from:to:)`.
- Produces: `WorkspaceDashboardColumn(session: WorkspaceSession)` — la usa Task 3 como columna izquierda.

- [ ] **Step 1: Crear la vista**

`WorkspaceDashboardColumn.swift`. Las secciones Processes/Branch se MUEVEN verbatim del `sidebar` actual (mismos `SectionHeader`, mismo `ForEach` con los mismos closures a `session.supervisor` y `session.selectedTab`, mismos spacing tokens que usa hoy el sidebar). Estructura completa:

```swift
import SwiftUI

/// Left column of the workspace window: live project dashboard.
/// Read-only surface — all editing lives in ProjectFormView.
struct WorkspaceDashboardColumn: View {
    let session: WorkspaceSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: /* mismo gap que el sidebar actual */) {
                headerCard
                branchSection      // movido verbatim (incluye su `if let`)
                processesSection   // movido verbatim
                quickLinksSection
                sessionSection
            }
            .padding(/* mismo padding que el sidebar actual */)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ActivityDot(isActive: !session.interactiveExited)
                Text(session.projectName)
                    .font(.headline)
                Spacer()
            }
            Text(session.root.path)
                .font(.caption.monospaced())
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Quick Links")
            QuickLinksPanel(projectID: session.projectId, isReadOnly: true, hideTitle: true)
        }
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Session")
            TimelineView(.periodic(from: session.openedAt, by: 60)) { context in
                Label(
                    WorkspaceSessionClock.elapsedLabel(from: session.openedAt, to: context.date),
                    systemImage: "clock"
                )
                .font(.callout)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            }
        }
    }
}
```

(`QuickLinksPanel` funciona acá porque la escena workspace ya inyecta `projectStore` — verificado en `DevtailApp.swift` L84-99. `isReadOnly: true` oculta el toggle Edit/Done: solo tap-to-open.)

- [ ] **Step 2: Usarla en `WorkspaceRootView`**

En `WorkspaceRootView.swift`: borrar la property `sidebar` (L97-130) y en el `HSplitView` reemplazar `sidebar` por:

```swift
WorkspaceDashboardColumn(session: session)
    .frame(minWidth: 220, maxWidth: 300)
```

(el ancho definitivo 260–340 y el lado izquierdo llegan en Task 3).

- [ ] **Step 3: Eliminar el snapshot `quickLinks` de `WorkspaceSession`**

Con `QuickLinksPanel` leyendo el store en vivo, el snapshot `let quickLinks: [(title: String, url: String)]` de `WorkspaceSession` queda sin consumidores (su único lector era el sidebar). Borrar: la propiedad, su parámetro de init, y su población en `openSession(for:)` (`project.quickLinks.sorted { $0.order < $1.order }.map { ... }`). En `WorkspaceSessionsHolderTests.swift`, borrar o ajustar los asserts del snapshot (tests de backfill del v1 — "session branch/quickLinks population"): conservar los de `currentBranch`, quitar los de `quickLinks`.

- [ ] **Step 4: Suite completa verde**

```bash
pgrep -fl xcodebuild || echo clear
xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet
```
Expected: PASS (283 + los nuevos de Task 1 − los asserts de snapshot borrados).

- [ ] **Step 5: Commit**

```bash
git add -A Devtail/Features/Workspace DevtailTests/Features/Workspace Devtail.xcodeproj/project.pbxproj
git commit -m "feat(workspace): project dashboard column with live quick links and session clock"
```

---

### Task 3: Tres columnas + placeholder del file tree

**Files:**
- Create: `Devtail/Devtail/Features/Workspace/Views/Components/FileTreePlaceholderColumn.swift`
- Modify: `Devtail/Devtail/Features/Workspace/Views/WorkspaceRootView.swift` (body, L17-30)

**Interfaces:**
- Consumes: `WorkspaceDashboardColumn` (Task 2).
- Produces: el layout final de 3 columnas; `FileTreePlaceholderColumn()` es el punto de anclaje del Ciclo 2.

- [ ] **Step 1: Crear el placeholder**

```swift
import SwiftUI

/// Right column placeholder. Cycle 2 (file tree + viewer) mounts here.
struct FileTreePlaceholderColumn: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "folder")
                .font(.title2)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Text("Files")
                .font(.headline)
                .foregroundStyle(DevtailTokens.Colors.textSecondary)
            Text("Coming soon")
                .font(.caption)
                .foregroundStyle(DevtailTokens.Colors.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Reordenar el `HSplitView` a 3 columnas**

Body final de `WorkspaceRootView`:

```swift
var body: some View {
    HSplitView {
        WorkspaceDashboardColumn(session: session)
            .frame(minWidth: 260, maxWidth: 340)

        VStack(spacing: 0) {
            tabRow
            terminalArea
        }
        .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)

        FileTreePlaceholderColumn()
            .frame(minWidth: 220, maxWidth: 300)
    }
    .navigationTitle(session.projectName)
    .onDisappear { holder.close(projectId: session.projectId) }
}
```

`tabRow`, `terminalArea`, `deadShellOverlay` y el `onDisappear` NO se tocan. La ventana default (1200×760) acomoda 260+640+220 = 1120; no cambiar `defaultSize`.

- [ ] **Step 3: Suite completa verde**

```bash
pgrep -fl xcodebuild || echo clear
xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet
```
Expected: PASS, mismo conteo que Task 2.

- [ ] **Step 4: Commit**

```bash
git add Devtail/Features/Workspace/Views Devtail.xcodeproj/project.pbxproj
git commit -m "feat(workspace): three-column layout with file tree placeholder"
```

---

### Task 4: Edición en `ProjectFormView` (modo edición)

ANTES de adelgazar el hub (Task 5), la edición de layout/panes/quick links tiene que existir en el form — nunca un commit sin hogar para la edición. Hoy `ProjectFormView` NO edita nada de eso (verificado). Las secciones nuevas aparecen SOLO en modo edición (`isEditMode`) y operan en vivo sobre el store — la misma semántica inmediata que tenían en `DashboardDetailView` (el form snapshot/submit existente sigue gobernando solo name/directory/launchTarget).

**Files:**
- Modify: `Devtail/Devtail/Features/ContextSwitcher/Views/ProjectFormView.swift` (body L37-56 + secciones nuevas)

**Interfaces:**
- Consumes: `WorkspaceLayoutPicker(selected:onSelect:axis:layouts:)`, `WorkspacePaneEditRow` (firma completa en su archivo: `projectRoot`, `initial*`, `detectorRegistry`, `onSave(7 params)`, más el resto de closures — COPIAR la instanciación exacta desde `DashboardDetailView.paneEditMode`/`paneAddMode` L64-133, que en este task todavía existen), `QuickLinksPanel(projectID:hideTitle:)`, y de `ProjectStore`: `addWorkspacePane(label:relativeCwd:command:layoutSlot:stack:isFrontend:localhostUrl:environment:to:)`, `updateWorkspacePane(_:label:relativeCwd:command:stack:isFrontend:localhostUrl:environment:)`, `deleteWorkspacePane(_:)`, `setLayout(for:layout:)`.
- Produces: el hogar único de edición; Task 5 depende de esto.

- [ ] **Step 1: Agregar las tres secciones al body en modo edición**

En el `VStack` del body, después de `preview` y antes de `actions`, agregar:

```swift
if isEditMode, let project = editingProject {
    layoutSection(for: project)
    processesSection(for: project)
    quickLinksSection(for: project)
}
```

donde `editingProject` es el `Project` que el form ya carga en modo edición (usar la referencia existente con la que el form hace el load; si hoy solo guarda el id, resolverlo vía `store.projects.first(where:)` como hace `DevtailApp` L91).

Secciones:

```swift
private func layoutSection(for project: Project) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        SectionHeader(title: "LAYOUT")
        WorkspaceLayoutPicker(
            selected: project.layout,
            onSelect: { store.setLayout(for: project, layout: $0) },
            axis: .horizontal
        )
    }
}

private func processesSection(for project: Project) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        SectionHeader(title: "PROCESSES")
        ForEach(project.panes.sorted(by: { $0.label < $1.label })) { pane in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pane.label).font(.callout)
                    Text(pane.command)
                        .font(.caption.monospaced())
                        .foregroundStyle(DevtailTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Edit") { editingPane = pane }
                Button(role: .destructive) {
                    store.deleteWorkspacePane(pane)
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        Button {
            isAddingPane = true
        } label: {
            Label("Add process", systemImage: "plus")
        }
    }
}

private func quickLinksSection(for project: Project) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        SectionHeader(title: "QUICK LINKS")
        QuickLinksPanel(projectID: project.id, hideTitle: true)
    }
}
```

(Si `project.panes` no es el nombre real de la relación, usar el que use `DashboardDetailView.sortedPanes` — copiar su sort también.)

- [ ] **Step 2: Sheet de edición/alta de pane**

Nuevos `@State`: `editingPane: WorkspacePane?`, `isAddingPane = false`. Presentar `WorkspacePaneEditRow` en sheet, COPIANDO la instanciación exacta (incl. `detectorRegistry` y todos los closures) desde `DashboardDetailView.paneEditMode` (L64-133):

```swift
.sheet(item: $editingPane) { pane in
    // WorkspacePaneEditRow con initial* desde `pane`,
    // onSave → store.updateWorkspacePane(pane, label:..., relativeCwd:..., command:..., stack:..., isFrontend:..., localhostUrl:..., environment:...)
    // cierre del sheet en onSave/onCancel
}
.sheet(isPresented: $isAddingPane) {
    // WorkspacePaneEditRow con initial* vacíos,
    // onSave → store.addWorkspacePane(label:..., relativeCwd:..., command:..., stack:..., isFrontend:..., localhostUrl:..., environment:..., to: project)
}
```

(`layoutSlot` usa su default `-1` — los slots están retirados del flujo.)

- [ ] **Step 3: Suite completa verde**

```bash
pgrep -fl xcodebuild || echo clear
xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet
```
Expected: PASS (las secciones nuevas reutilizan store methods ya testeados en `ProjectStoreWorkspacePaneTests`/`ProjectStoreQuickLinkTests`; no hay tests de vistas en la suite).

- [ ] **Step 4: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/ProjectFormView.swift
git commit -m "feat(hub): edit processes, quick links and layout from the project form"
```

---

### Task 5: Hub delgado (`DashboardDetailView`)

Con la edición ya viviendo en el form (Task 4), el detail del hub se reduce a welcome.

**Files:**
- Modify: `Devtail/Devtail/Features/ContextSwitcher/Views/Components/DashboardDetailView.swift` (819 líneas → mucho menos)

**Interfaces:**
- Consumes: nada nuevo.
- Produces: hub delgado. Nadie más consume las piezas borradas (verificado: `WorkspaceLayoutThumbnail` con slot-menus y `QuickLinksPanel` editable solo se usaban acá; `WorkspaceLayoutPicker` ahora vive también en `ProjectFormView`).

- [ ] **Step 1: Borrar edición y secciones**

Eliminar de `DashboardDetailView`:
- `layoutSection` (L616-660) y sus helpers de slots: `slotLabels(for:)`, `slotMenuContent(for:)`, `filledSlotMenu`, `emptySlotButton`.
- `quickLinksSection` (L664-673).
- `paneEditMode(for:)` y `paneAddMode` (L64-133) y los `@State` `editingPaneID`, `isAddingPane`, `pendingSlotForNewPane`.
- Del ladder del body (L33-43) quedan solo: `isShowingDetails ? detailsMode : browsingMode`.

`browsingMode` queda: `ScrollView { VStack(spacing: gapSection) { heroHeader } }` (borrar el divider `Rectangle` y las secciones idas).

- [ ] **Step 2: Verificar qué conserva el hero**

`heroHeader` NO se toca: ActivityDot + nombre + resumen "\(project.layout.displayName) · N panes" + path + menú (View details / Edit project / Delete project) + VSCode + Resume (con su alert de branches) + Launch (`store.prepareLaunch` + `openWindow`). `detailsMode` (read-only) y el `confirmationDialog` de delete se conservan.

- [ ] **Step 3: Sweep de referencias muertas**

```bash
rg -n "slotMenuContent|filledSlotMenu|emptySlotButton|slotLabels|paneEditMode|paneAddMode|pendingSlotForNewPane" Devtail/
```
Expected: cero hits fuera de este archivo (y cero dentro tras el borrado). Si `WorkspaceLayoutThumbnail` pierde su modo assignment-with-menus como único consumidor, NO borrar el componente (lo usa `WorkspaceLayoutPicker` internamente en modo bare) — solo puede quedar código muerto el parámetro `onSlotMenu`; dejarlo (dormido, como las columnas del modelo).

- [ ] **Step 4: Suite completa verde**

```bash
pgrep -fl xcodebuild || echo clear
xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet
```
Expected: PASS (no existen tests de esta vista; los store tests no se tocan).

- [ ] **Step 5: Commit**

```bash
git add Devtail/Features/ContextSwitcher/Views/Components/DashboardDetailView.swift
git commit -m "refactor(hub): slim detail view to JetBrains-style welcome"
```

---

### Task 6: Ledger, suite final y checkpoint manual

**Files:**
- Modify: `.superpowers/sdd/progress.md` (nueva sección del ciclo)

- [ ] **Step 1: Ledger**

Agregar al final de `.superpowers/sdd/progress.md`:

```
=== Workspace 3 columnas + hub delgado · Ciclo 1 ===
Base: <sha de main> · spec: docs/superpowers/specs/2026-07-15-workspace-tres-columnas-design.md · plan: docs/superpowers/plans/2026-07-15-workspace-tres-columnas.md · branch: feat/workspace-tres-columnas
Task 1..5: <estado y notas por task>
```

- [ ] **Step 2: Suite completa final**

```bash
pgrep -fl xcodebuild || echo clear
xcodebuild test -project Devtail.xcodeproj -scheme Devtail -destination 'platform=macOS' -quiet
```
Expected: PASS. Registrar el conteo final en el ledger.

- [ ] **Step 3: Commit del ledger**

```bash
git add .superpowers/sdd/progress.md
git commit -m "docs(sdd): cycle 1 progress ledger"
```

- [ ] **Step 4: USER CHECKPOINT (Javier, manual — bloquea el merge)**

En la app real (build desde Xcode, launch de un proyecto con procesos y quick links):
1. La ventana workspace muestra 3 columnas; la izquierda tiene header (nombre+path+dot), branch, procesos operables (start/stop/restart + tab switch), quick links que abren, y el reloj de sesión avanzando.
2. La columna derecha muestra el placeholder "Files — Coming soon" y se puede redimensionar.
3. El terminal y las tabs de procesos funcionan igual que antes (scrollback intacto al cambiar tabs, restart del shell muerto).
4. El hub quedó delgado: hero + Launch/Resume + View details + Edit/Delete + VSCode, sin layout ni quick links.
5. "Edit project" abre el form con las secciones Layout / Processes / Quick Links funcionando (alta, edición y borrado de un proceso; alta/borrado de un quick link — y el cambio se refleja en vivo en la columna del workspace abierto).
6. Cerrar la ventana workspace mata los procesos (verificar con `lsof -i :<puerto>` que no quedan huérfanos).

Merge a `main` solo con checkpoint PASSED.
