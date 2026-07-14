# Terminal embebida y procesos gestionados (v1)

## Contexto y decisión

Devtail lanza Ghostty externo vía AppleScript. La consola no embebida era lo
único que expulsaba al usuario hacia otra herramienta; se decidió (2026-07-14)
que Devtail es la plataforma principal y Estación (Tauri+Angular) queda como
laboratorio — sus diseños probados se portan como diseño, no como código.

Decisiones cerradas en brainstorming:

- **Soltar App Sandbox** (herramienta personal, distribución directa; se
  mantiene Hardened Runtime). Sin sandbox no hay PTY ni procesos gestionados.
- **Motor**: SwiftTerm detrás de un protocolo `TerminalEngine` (primera
  dependencia SPM del proyecto). Swap futuro a libghostty cuando su API
  estabilice, sin tocar consumidores.
- **Reemplazo directo** del camino AppleScript→Ghostty (Estación queda como
  red de seguridad operativa durante la migración).
- **Ventana de workspace por proyecto**; el dashboard/menubar quedan como
  gestor y launcher.
- **Los layouts de panes se retiran**: existían para correr procesos en splits
  de Ghostty. Los dev-servers pasan a ser procesos gestionados (modelo
  Estación); la ventana lleva UNA terminal interactiva.
- **V1 = terminal + procesos básicos** (start/stop/restart con log), para que
  el flujo diario "lanzar proyecto → servers arriba" sobreviva al reemplazo
  desde el día uno.

## Arquitectura

### Sandbox

Se quita `com.apple.security.app-sandbox` de `Devtail.entitlements` (Hardened
Runtime se queda). Mueren `WorkspaceLauncher` (AppleScript), su entitlement
`apple-events` scoped a Ghostty, y `WorkspaceActivityMonitor`. Los
security-scoped bookmarks dejan de ser necesarios pero NO se tocan en v1
(limpieza futura; borrar columnas/flujos no aporta hoy).

### Módulo nuevo: `Features/Workspace/`

Hermano de `ContextSwitcher`, misma disciplina de capas
(Models → Services → Stores → Views). ContextSwitcher = gestión (dashboard,
proyectos, quick links); Workspace = trabajo.

### `TerminalEngine` (protocolo)

Abstrae el emulador. Implementación v1: `SwiftTermEngine`.

- Crear sesión PTY (cols/rows, cwd, comando).
- Escribir al stdin, resize, kill.
- Exponer la vista (`NSViewRepresentable` sobre la view de SwiftTerm).
- Notificar muerte del proceso de la sesión.

Todo consumidor (terminal interactiva y supervisor de procesos) habla con el
protocolo, nunca con SwiftTerm directo — para eso existe: mockearlo en tests y
swappear motor sin reescribir.

### `ProcessSupervisor` (@Observable)

Gestiona los dev-servers. **Enfoque "todo es PTY"**: cada proceso corre en su
propia sesión PTY del mismo engine; su log ES una vista de terminal de
solo-lectura (colores ANSI, scrollback y selección gratis; los servers
detectan TTY y no bufferean).

Lecciones de Estación aplicadas por diseño:

- Spawn vía **login shell interactivo** (`$SHELL -ilc "<command>"`): hereda
  PATH de Homebrew/nvm/zoxide aunque la app se abra desde Finder.
- El hijo se lanza como **líder de grupo de proceso** (`setsid`); stop hace
  `killpg(SIGTERM)` → timeout ~3s → `SIGKILL` al grupo. Sin huérfanos de
  `--watch` sosteniendo puertos, por construcción.
- **Restart limpia el log** (restart con log sucio confunde).

## Modelo de datos y migración

`WorkspacePane` ya es una definición de proceso (`relativeCwd`, `command`,
`stack`, `isFrontend`/`localhostUrl`, `lastKnownBranch`). Se conserva la clase
`@Model` (sin migración destructiva de SwiftData); el dominio y la UI la
tratan como "Proceso".

- **Dormidos** (columnas presentes, ignoradas): `layoutSlot`,
  `Project.layout`, `Project.launchTarget`. Limpieza en migración futura.
- **Vivos con el mismo rol**: `isFrontend`/`localhostUrl` (auto-abrir browser
  al levantar), `lastKnownBranch` (branch-drift del Resume, intacto).
- **No se persiste** el estado de la sesión de terminal (scrollback, historia).
  Abrir el workspace es siempre fresco: terminal en la raíz + auto-start de
  todos los procesos definidos (paridad con el comportamiento actual).
  Restauración fina de sesión = sub-proyecto futuro.

## Ciclo de vida

Lanzar proyecto → abre/enfoca su ventana de workspace → chequeo de
branch-drift (flujo actual) → terminal interactiva en la raíz → auto-start de
cada proceso.

Estados por proceso: `stopped → starting → running → exited(code)`. El
supervisor observa la muerte del PTY y actualiza; la UI reacciona por
`@Observable`. Cerrar la ventana (o quit de la app) mata todos los grupos con
el mismo SIGTERM→SIGKILL.

## UI de la ventana de workspace

SwiftUI con `DevtailTokens` (misma identidad visual):

- **Área principal**: terminal interactiva, protagonista.
- **Sidebar derecha angosta**: tarjetas de proceso (nombre, punto de estado,
  start/stop/restart) + branch actual + quick links.
- **Tabs sobre el área principal** (`terminal | back | front…`): tocar una
  tarjeta muestra su log. La terminal siempre primera.
- **Las vistas de terminal nunca se destruyen al cambiar de tab — se ocultan.**
  Las `NSView` viven retenidas en el supervisor; la UI decide cuál se muestra
  (`ZStack` + hidden, no `if/else`). Si SwiftUI desmonta el `NSView`, se
  pierde scrollback y muere la sesión (lección Estación).

Fuera de v1: visor de archivos, panel docker, imágenes al agente, divisores
redimensionables. La estructura (área principal con tabs) les deja lugar sin
construir nada especulativo.

Dashboard y menubar no cambian salvo el efecto de "Launch": abrir esta ventana
en vez de AppleScript.

## Errores

- **Spawn falla** (cwd inexistente, shell rara): tarjeta en estado de error
  con mensaje; el log muestra lo que el shell alcanzó a decir. Nada tumba el
  workspace.
- **Comando no encontrado**: visible en el log del proceso (es un shell real).
- **Muerte inesperada**: `exited(code)` en la tarjeta, log disponible,
  restart a un click.
- **Cierre/quit con servers corriendo**: teardown mata todos los grupos
  (probado explícitamente).
- **Branch drift**: confirmación actual, sin cambios.

## Testing

Swift Testing, patrón existente del repo:

- **Puros**: armado de `$SHELL -ilc` (quoting), resolución de cwd, máquina de
  estados (transiciones válidas).
- **`ProcessSupervisor` contra `MockTerminalEngine`**: spawn/stop/restart,
  restart limpia log, auto-start al abrir, trigger de browser en `isFrontend`,
  kill-group en teardown.
- **Migración**: proyecto legacy con layout/slots abre como lista de procesos.
- **Checkpoint manual anti-huérfanos** (criterio de éxito nº1): levantar un
  watcher real, cerrar la ventana, verificar con `lsof` que el puerto quedó
  libre.
- No se testea SwiftTerm por dentro (dependencia).

## Qué NO se hace (YAGNI)

- No libghostty en v1 (el protocolo deja el swap abierto).
- No splits/layouts de terminal.
- No persistencia de sesión de terminal.
- No borrar columnas dormidas ni el código de bookmarks en v1.
- No docker panel, visor de archivos ni agente con imágenes (sub-proyectos
  propios).
