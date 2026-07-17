# Retiro del dashboard — Implementation Plan (Ciclo 7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retirar la ventana del dashboard; el popover de la barra de menú absorbe create/delete/VSCode/Resume/sort; ventana mínima "New Project" para la creación.

**Architecture:** El popover ya tiene el gradiente y el launch path idéntico (`store.prepareLaunch` + `openWindow(workspace)`). Se porta la lógica huérfana del dashboard (delete, resume con branch-detection, sort) a `MenuBarRootView`/`PopoverAccordionItem`, se crea una escena `Window` mínima para el form en modo create, y se borra el sistema dashboard completo (vistas + intents + escena).

**Tech Stack:** Swift 6 (MainActor default), SwiftUI, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-07-16-retiro-dashboard-design.md` (mapa de referencias exactas en la exploración: gradiente DashboardRootView:87-97 ya duplicado en MenuBarRootView:118-128; launch paths idénticos; inventario de huérfanos §6).

## Global Constraints

- Código/comentarios/UI en inglés; conventional commits sin atribución de IA.
- Protocolo OOM: un solo runner xcodebuild, `pgrep -f xcodebuild` antes de cada corrida, `-jobs 4`.
- El launch path del popover NO cambia (`store.prepareLaunch` + `openWindow(id: WindowID.workspace, value:)`).
- `ProjectFormView` NO se modifica (solo se monta en la ventana nueva en modo create).
- Suite base: 445+ casos / 0 fallos sobre 10e1c83 (+ separador a6665a6 apilado en esta branch).

---

### Task 1: Ventana "New Project" + Cmd+N + retiro de intents

**Files:**
- Create: `Devtail/Features/ContextSwitcher/Views/NewProjectWindowView.swift`
- Modify: `Devtail/App/DevtailApp.swift` (escena nueva `WindowID.newProject`, Cmd+N repunteado, retiro de `DashboardIntentHolder`/`DashboardIntent` y su inyección)
- Modify: `Devtail/Features/ContextSwitcher/Views/MenuBarRootView.swift` (los 3 `openWindow(id: WindowID.dashboard)` → abren la ventana nueva o se retiran según el caso; `openDashboardForCreate` → `openNewProjectWindow`; el path de `openDashboardForProject`/`.showProject` se retira en Task 3 junto con el link)

**Interfaces:**
- Produces: `WindowID.newProject = "devtail.newProject"`; `NewProjectWindowView` = gradiente (mismos 3 stops, extraer a un helper compartido si queda DRY: `DevtailGradients.appBackground`) + `ProjectFormView(projectID: nil, onDismiss: { dismiss() }, isDirty: $_)` con `@Environment(\.dismiss)`; escena `Window("New Project", id: WindowID.newProject)` ~680×620, `.windowResizability(.contentSize)`, `.defaultLaunchBehavior(.suppressed)`, con environments necesarios (`projectStore`, `modelContainer`, `appSettings`).

- [ ] **Step 1:** Crear vista + escena + WindowID; Cmd+N (`CommandGroup(replacing: .newItem)`) abre `WindowID.newProject` sin intents.
- [ ] **Step 2:** `MenuBarRootView`: "New project" (footer + empty state) → `openWindow(id: WindowID.newProject)` + `NSApp.activate`. Retirar `DashboardIntentHolder` de DevtailApp (definición, instancia, inyecciones) y su consumo en MenuBarRootView. NOTA: `DashboardRootView.consumePendingIntent` queda temporalmente rota de compilar — si es así, retirarla ya en este task (el resto de DashboardRootView se borra en Task 3), preservando compilación verde por task.
- [ ] **Step 3:** Build + suite completa. Expected: PASS.
- [ ] **Step 4: Commit** `feat(hub): minimal new-project window replaces dashboard create flow`

---

### Task 2: El popover absorbe delete, VSCode, Resume y sort

**Files:**
- Modify: `Devtail/Features/ContextSwitcher/Views/MenuBarRootView.swift` (sort menu en header; estado `SidebarSortMode` portado con su persistencia; alert de resume)
- Modify: `Devtail/Features/ContextSwitcher/Views/Components/PopoverAccordionItem.swift` (context menu: Open in VSCode / Delete project… con confirmación; botón Resume condicional en la fila expandida)

**Interfaces:**
- Consumes: `store.openInVSCode(project:)`, `store.deleteProject(project)`, `store.detectBranchChanges(for:)` (portar la semántica exacta de `DashboardDetailView.handleResumeTap`/resume alert, líneas ~437-479 pre-borrado — leerla ANTES de que Task 3 la borre), `SidebarSortMode` (localizar dónde persiste — mudarlo tal cual).
- Produces: popover completo como único punto de entrada.

- [ ] **Step 1:** Context menu en la fila (VSCode + Delete con `confirmationDialog`; el diálogo puede vivir en el item o elevarse a MenuBarRootView — elegir lo que funcione en popover de MenuBarExtra y anotarlo).
- [ ] **Step 2:** Resume: fila expandida muestra Resume si `project.lastLaunchedAt != nil`; branch-change alert portado (Continue → launch igual; Cancel → no-op). Mismo launch path.
- [ ] **Step 3:** Sort menu compacto en el header del popover (recency/alphabetical) reutilizando `SidebarSortMode` + persistencia; la lista respeta el orden y la búsqueda existente.
- [ ] **Step 4:** Build + suite. Expected: PASS.
- [ ] **Step 5: Commit** `feat(hub): popover absorbs delete, vscode, resume and sort`

---

### Task 3: Borrado del sistema dashboard + sweep

**Files:**
- Delete: `DashboardRootView.swift`, `DashboardDetailView.swift`, `DashboardSidebarItem.swift` (localizar path real)
- Modify: `DevtailApp.swift` (escena dashboard + `WindowID.dashboard` fuera), `PopoverAccordionItem.swift` ("View in Dashboard…" + `onOpenDashboard` fuera), `MenuBarRootView.swift` (`openDashboard`/`openDashboardForProject` fuera; el botón "Manage…" del footer se retira o repuntea a nada — retirarlo)
- Test: actualizar lo que rompa (la exploración dice que ningún test referencia estas vistas)

**Interfaces:**
- Consumes: Tasks 1-2 completos (nada del dashboard debe tener ya callers vivos).

- [ ] **Step 1:** Borrar archivos + referencias; sweep obligatorio: `rg -n "Dashboard|dashboardIntent|WindowID.dashboard" Devtail/ DevtailTests/` → cero hits (salvo comentarios históricos que se corrigen). OJO: `DevtailTokens.dashboardWidth/Height/sidebarWidth` y `Spacing.dashboardPadding` — dashboardPadding tiene callers vivos (settings tab, markdown view): CONSERVARLO; los width/height quedan sin callers → borrarlos.
- [ ] **Step 2:** Build + suite completa. Expected: PASS.
- [ ] **Step 3: Commit** `feat(hub): retire the dashboard window and its intent system`

---

### Task 4: Suite final + ledger + review de branch

- [ ] **Step 1:** Suite completa; conteo. **Step 2:** Ledger. **Step 3:** Review final de branch (incluye el separador rail/panel apilado a6665a6) + fix wave si aplica. **Step 4:** `>>> PENDIENTE: USER CHECKPOINT (Javier)`: New Project por Cmd+N y popover; delete/VSCode en context menu; Resume con branch alert; sort; sin dashboard; separador rail/panel visible.
