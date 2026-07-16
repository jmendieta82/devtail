# Settings en el workspace + retiro del picker LAYOUT — Ciclo 5

**Fecha**: 2026-07-16 · **Aprobado por**: Javier (brainstorming 3 preguntas, respuestas A/A/A)

## Problema

Editar un proyecto hoy obliga a saltar del workspace a la ventana del dashboard (hub): `ProjectFormView` se presenta inline en `DashboardRootView.detail` vía `DashboardMode.editingProject`. Además el form muestra la sección LAYOUT (`WorkspaceLayoutPicker`), huérfana desde que los ciclos 1–4 reemplazaron el modelo de grilla por tabs efímeras.

## Decisiones (cerradas con Javier)

1. **El hub queda solo para crear y lanzar.** La edición vive únicamente dentro del workspace. Se eliminan todos los entry points de edición del hub.
2. **Engranaje al fondo del rail, settings como tab efímera en el centro.** Estilo VS Code. El panel lateral (files/processes) no cambia.
3. **Retiro de LAYOUT solo en UI.** `Project.layout` y `WorkspacePane.layoutSlot` quedan dormidos en el modelo, sin migración (precedente: LaunchTarget picker en v1).

## Diseño

### Tab de settings

- Caso nuevo `WorkspaceTab.settings` (enum runtime, sin persistencia — igual que los demás casos).
- `ActivityBar`: los items de `SidePanelView` quedan arriba; tras el `Spacer` va un botón engranaje (`gearshape`) que hace `session.selectedTab = .settings`. No toca `session.sidePanel`. Iluminado (accentPrimary) cuando la tab settings está seleccionada.
- Tab row: chip `WorkspaceTabChip` (icono `gearshape`, título "settings") visible solo mientras `selectedTab == .settings`, con ✕ cuyo cierre hace fallback a `.agent` — espejo del comportamiento de tabs de archivo. Cerrar la tab es puramente visual: no descarta nada (el form guarda vía store en el momento).
- Render: montada condicionalmente en el ZStack de `terminalArea` (como `FileViewerTabView` — no hay PTY que preservar), envuelta en `WorkspaceSettingsTabView`.

### Contenido: reutilización de ProjectFormView

- `WorkspaceSettingsTabView` presenta `ProjectFormView(projectID: session.projectId, ...)` en modo edición. El entorno del workspace ya inyecta `modelContainer` y `ProjectStore` (`DevtailApp` líneas 94–110) — no hay plomería nueva de datos.
- `onDismiss` del form (Save o Close) selecciona `.agent` (cierra la tab settings).
- Sin sección LAYOUT (ver abajo).

### Reflejo en vivo: ProcessSupervisor.reconfigure

`configure(panes:root:)` actual derriba todo (`shutdownAll` + instancias nuevas). Se agrega `reconfigure(panes:)` con diff por `pane.id` (que ya es la identidad de `ManagedProcess`):

- **Pane conservado**: el `ManagedProcess` existente sobrevive con su sesión y estado intactos. Sus campos (`name`, `command`, `cwd`, `isFrontend`, `localhostUrl`) pasan de `let` a `private(set) var` y se actualizan en el diff — un proceso corriendo sigue corriendo con el comando viejo hasta el próximo restart/start, que ya toma el nuevo.
- **Pane borrado**: `close(_:)` (stop + descartar sesión — la tab desaparece por el guard `session != nil`).
- **Pane nuevo**: aparece como card `stopped` (no auto-arranca — directiva vigente).
- **Panes en blanco**: se siguen filtrando (mismo contrato que `configure`).
- El orden final respeta `pane.order`.

Disparo: el form guarda los panes al instante (`store.addWorkspacePane` / `updateWorkspacePane` / `deleteWorkspacePane` desde sus sheets), así que `WorkspaceSettingsTabView` observa la firma de los panes del proyecto (ids + campos relevantes + orden) y llama `session.supervisor.reconfigure` cuando cambia. Esto cubre Save y también los caminos inmediatos de panes.

### Hub: retiro de la edición

- `DashboardDetailView`: se elimina "Edit project" del menú de acciones.
- `MenuBarRootView.openDashboardForProject` (intent `.editProject`): la acción pasa a abrir el dashboard con el proyecto **seleccionado en modo browsing** (no en edición).
- `DashboardRootView`: se eliminan `DashboardMode.editingProject`, `startEditing`, y la rama `.editProject` de `consumePendingIntent`. `DashboardIntent.editProject` se reemplaza por `.showProject(UUID)` (selección browsing).
- El modo create (`.creatingProject` + entry points New Project) queda intacto.

### Retiro del picker LAYOUT

- `ProjectFormView`: se elimina `layoutSection` (líneas 186–195) y su render en el bloque de edición (línea 47).
- `WorkspaceLayoutPicker` (vista) se borra; `ProjectStore.setLayout` queda sin callers y se borra con sus tests directos.
- `Project.layout`, `WorkspacePane.layoutSlot` y sus tests de modelo **quedan intactos** (dormidos).

## Límites aceptados (disclosed)

- Renombrar el proyecto o cambiar su directorio desde settings **no** se propaga a la sesión abierta (`projectName`/`root` son `let` en `WorkspaceSession`): título de ventana y cwd de terminales nuevas se actualizan al reabrir el workspace. Los procesos conservados tampoco recalculan `cwd` hasta reabrir si solo cambió el directorio raíz.
- `isDirty` del form sigue trackeando solo name/directory/launchTarget (los panes guardan al instante) — sin cambios.

## Fuera de alcance

Limpieza del modelo layout (campos + migración), colapso/persistencia del panel lateral, search/git en el rail, cualquier otro deferred.

## Testing

- `ProcessSupervisor.reconfigure` (TDD, pieza de mayor riesgo): conservado-corriendo sobrevive con sesión; conservado-detenido actualiza comando; borrado se cierra; nuevo aparece stopped; blanco filtrado; orden respetado; comando cambiado en proceso corriendo aplica tras restart.
- `WorkspaceTab.settings`: fallback a `.agent` al cerrar; selección desde el rail.
- Suite existente en verde: `ProcessSupervisorTests` (configure intacto), `WorkspaceSessionOpenFilesTests`, `WorkspaceSessionsHolderTests`, `WorkspaceTabChipTests`.
