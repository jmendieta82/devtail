# Agente Claude en pane (Ciclo 3)

## Contexto y decisión

Cierre de la visión workspace (Ciclos 1-2 mergeados, e7cc642). Hoy claude solo
puede correrse a mano en la tab terminal; el toggle "Run Claude Code" del alta
de proyecto siembra un pane gestionado (read-only) con `command: "claude"` —
una TUI viva donde no se puede escribir (trap confirmado en el checkpoint del
Ciclo 2). El Ciclo 3 trae el agente como tab interactiva de primera clase,
con imágenes por bracketed paste (mecanismo validado en Estación).

Decisiones cerradas en diseño (2026-07-15, con Javier):

- **Tab `agent` de primera clase**: `WorkspaceTab.agent`, segunda en la tab
  row (`terminal | agent | procesos | archivos`). Sesión interactiva propia
  en `WorkspaceSession`, espejando la maquinaria del terminal: retención
  ZStack, guard de identidad en `onExit`, overlay de restart al morir.
- **Auto-launch**: el agente se spawnea al abrir el workspace
  (`[zsh, "-ilc", agentCommand]` — login shell, PATH completo). Principio
  Estación: hospedar el agente.
- **Comando configurable, default limpio (opción C)**:
  `AppSettings.agentCommand` (UserDefaults, default `"claude"`). Quien quiera
  resume configura `claude --continue`; sin lógica especial nuestra (el caso
  "primera vez sin conversación" hacía riesgoso el resume por default).
- **Imágenes vía paste**: subclase `AgentTerminalView` overrideando el
  `paste(_:)` `open` de SwiftTerm — imagen en clipboard (bitmap o archivo) →
  PNG en temp dir propio → `insertText(path, isPaste: true)`; SwiftTerm
  envuelve en `\x1b[200~…\x1b[201~` gratis (Claude activa el modo 2004) y lo
  muestra como `[Image #N]`. Texto normal sigue al `super`. Temp files se
  limpian al terminar la sesión. Drag-drop diferido (SwiftTerm sin drop
  nativo).
- **Muere el toggle "Run Claude Code"**: se quita del alta;
  `ProjectStore.createProject` pierde el parámetro (el root pane se siembra
  siempre con comando vacío). Panes existentes con `claude` NO se migran
  (datos del usuario; se limpian a mano en Edit project).
- **Settings deja de ser placeholder**: form mínimo con el campo Agent
  command (persistencia inmediata a UserDefaults).

## Arquitectura

- `WorkspaceTab` gana `case agent`.
- `WorkspaceSession` gana `fileprivate(set) var agent: TerminalSession` +
  `var agentExited = false`. `WorkspaceSessionsHolder` (que recibe
  `AppSettings` por init — hoy no está inyectado en ningún lado) spawnea el
  agente en `openSession` (`TerminalSessionConfig(command: settings
  .agentCommand, cwd: root, readOnly: false, imagePaste: true)`), cablea
  `wireAgentExit` con guard de identidad, y expone `restartAgent(projectId:)`
  espejo de `restartInteractive`. `close`/`shutdownAll` terminan también la
  sesión del agente.
- `TerminalSessionConfig` gana `imagePaste: Bool = false`; `SwiftTermSession`
  elige la vista: readOnly → `ReadOnlyLocalProcessTerminalView`, imagePaste →
  `AgentTerminalView`, resto → `LocalProcessTerminalView`.
- `AgentTerminalView: LocalProcessTerminalView` overridea `paste(_:)`;
  la extracción de imagen del pasteboard y el guardado a temp viven en un
  helper testeable (`AgentImagePaste`: leer PNG del pasteboard —bitmap o
  file-URL de imagen—, guardar a `temporaryDirectory/devtail-agent-images-
  <uuid>/`, cleanup del dir).
- `AppSettings.agentCommand: String` con persistencia en `didSet` (guarda la
  referencia a `UserDefaults`); default y fallback de vacío → `"claude"`.
  `DevtailApp` instancia e inyecta `AppSettings` (hoy no se inyecta).
- UI: tab button "agent" tras "terminal"; `TerminalHostView(session.agent
  .view)` montada SIEMPRE en el ZStack con opacity/hitTesting por `.agent`;
  overlay "agent exited / Restart agent" espejo del deadShellOverlay.
- Settings window: reemplaza `ComingSoonView` por un form de un campo
  (TextField Agent command) sobre `AppSettings`.

## Testing

- TDD en stores/servicios: spawn del agente (config correcto, comando de
  settings, readOnly false), exit flag + stale-exit guard en ambas
  direcciones, restart, teardown (close termina interactive + agent +
  procesos), `AppSettings.agentCommand` (default, custom, vacío→fallback,
  persistencia), `AgentImagePaste` (pasteboard con bitmap → PNG; file-URL de
  imagen → PNG; solo texto → nil; save+cleanup del temp dir) usando
  `NSPasteboard(name:)` propio de test.
- Los mocks existentes ya sirven: `MockTerminalSession.written` graba
  `writeToStdin`; `MockTerminalEngine.configs` graba cada spawn.
- Vistas (tab, overlay, paste real en TUI): compile + checkpoint manual.
- Suite base a preservar: 314 casos, 0 fallos.

## Fuera de alcance

- Drag-drop de imágenes (SwiftTerm sin drop nativo).
- Migración automática de panes con `command: "claude"`.
- Comando de agente por-proyecto (YAGNI; global en Settings).
- Botón 📎 file-picker (Estación lo tenía; se evalúa tras el checkpoint).
- Hardening diferido de ciclos previos (sin cambios).
