# Apariencia de terminal configurable — Ciclo 6

**Fecha**: 2026-07-16 · **Aprobado por**: Javier ("que sea visual y no tanto un JSONconfig")

## Problema

La terminal central usa los defaults de SwiftTerm (fuente del sistema, paleta genérica, cursor parpadeante, sin padding). Javier venía de Ghostty con una config concreta: JetBrains Mono 14, Catppuccin Mocha, padding 12/8, cursor block sin parpadeo, copy-on-select y mouse oculto al tipear. Quiere esos valores en Devtail, configurables desde una UI visual en Settings — no defaults duros ni archivos de config.

## Decisiones

1. **Sección "Terminal" en Settings** (ventana existente), visual: tema con swatches de colores, picker de fuentes monoespaciadas instaladas, stepper de tamaño, toggles.
2. **Defaults = la config Ghostty de Javier**: Catppuccin Mocha, JetBrains Mono 14 (con fallback si no está instalada), block sin parpadeo, copy-on-select ON, mouse-hide ON.
3. **Aplicación en vivo** a todas las terminales (interactiva, agente, procesos).
4. **Padding 12/8 fijo** alrededor del área de terminal, con fondo igualado al tema.
5. Fuera de alcance: keybinds de splits, Cmd+T/W, confirm-close.

## Diseño

### Modelo: TerminalTheme + settings en AppSettings

- `TerminalTheme`: `id`, `name`, 16 colores ANSI + `background`, `foreground`, `cursor`, `selection`. Integrados (paletas canónicas publicadas): **Catppuccin Mocha** (default), Catppuccin Latte, Dracula, Solarized Dark, One Dark. Estructura estática (`TerminalTheme.builtIn`), lookup por id con fallback a Mocha.
- `AppSettings` gana (mismo patrón `didSet` → UserDefaults que `agentCommand`): `terminalThemeId: String`, `terminalFontName: String` ("JetBrainsMono-Regular", fallback en cascada a una monoespaciada del sistema si no resuelve), `terminalFontSize: Double` (14), `terminalCursorBlock: Bool` (true), `terminalCursorBlinks: Bool` (false), `terminalCopyOnSelect: Bool` (true), `terminalHideMouseWhileTyping: Bool` (true).
- `TerminalAppearance`: struct derivada de AppSettings que resuelve tema + NSFont concreto y sabe aplicarse a una vista de SwiftTerm: `apply(to: TerminalView)` — `font`, `installColors` (16 `Color` de componentes de 16 bits), `nativeBackgroundColor`/`nativeForegroundColor`/`caretColor`/`selectedTextBackgroundColor`, `getTerminal().setCursorStyle(_)`.

### Vista de terminal propia: DevtailTerminalView

`LocalProcessTerminalView` no expone copy-on-select ni keyDown overrideable (`keyDown` es `public`, no `open`). Se introduce `DevtailTerminalView: LocalProcessTerminalView` con dos flags (`copyOnSelect`, `hideMouseWhileTyping`) y dos overrides:

- `selectionChanged(source:)` (hook `open` de SwiftTerm): si `copyOnSelect` y hay selección (`getSelection()`), copia al pasteboard general.
- `send(source:data:)` (choke point `open` de todo keystroke — mismo mecanismo que ya usa `ReadOnlyLocalProcessTerminalView`): si `hideMouseWhileTyping`, `NSCursor.setHiddenUntilMouseMoves(true)` antes de delegar a super.

Rebase de la jerarquía: `LocalProcessTerminalView` plano → `DevtailTerminalView`; `ReadOnlyLocalProcessTerminalView` y `AgentTerminalView` pasan a extender `DevtailTerminalView` (sus overrides componen: el read-only pisa `send` tragando input y NO llama super del envío — conservar su contrato exacto).

### Aplicación: primera pintura + en vivo

- **Primera pintura**: `SwiftTermSession.init` (único punto de construcción de vistas) aplica la apariencia actual. El engine gana una dependencia inyectada `appearanceProvider: @MainActor () -> TerminalAppearance` (cableada en `DevtailApp` desde `AppSettings`); los mocks de test no cambian (protocolos `TerminalEngine`/`TerminalSessionConfig` intactos).
- **En vivo**: `TerminalHostView` lee `AppSettings` del environment y re-aplica en `updateNSView` cuando la apariencia cambia (guard de idempotencia: solo si difiere de la última aplicada, vía token/hash de apariencia). Como el modelo de retención mantiene TODAS las terminales montadas, esto cubre agente, interactiva y procesos sin registro adicional.
- Los flags de comportamiento (`copyOnSelect`, `hideMouseWhileTyping`) se setean en ambos puntos (cast a `DevtailTerminalView`).

### Padding y fondo

`WorkspaceRootView.terminalArea`: el ZStack gana `.padding(.horizontal, 12).padding(.vertical, 8)` y `.background` con el color de fondo del tema activo (leído de AppSettings), de modo que el marco alrededor de la terminal sea del mismo color y el padding se vea integrado. Los overlays (visor, settings, dead-shell) quedan dentro del mismo marco.

### Settings UI: sección "Terminal"

En `SettingsView` (Form grouped existente), nueva `Section("Terminal")`:

- **Theme**: fila por tema — nombre + swatch row (fondo + 8 colores ANSI representativos como circulitos) — selección por click con checkmark. Sin dropdown de texto.
- **Font**: `Picker` con las familias monoespaciadas instaladas (enumeración vía `NSFontManager`/descriptores fixed-pitch), cada nombre renderizado en su propia fuente; stepper de tamaño 10–20 (default 14).
- **Cursor**: toggle "Block cursor" y toggle "Blink".
- **Behavior**: toggles "Copy on select" y "Hide mouse while typing".
- La ventana de Settings crece de 420 a un ancho que acomode los swatches (~480).

## Límites aceptados (disclosed)

- Si JetBrains Mono no está instalada, el fallback es la primera monoespaciada disponible del sistema (p. ej. SF Mono/Menlo); el picker muestra lo que hay instalado.
- El cambio de tema/fuente en vivo re-renderiza las terminales; el scrollback conserva colores ya pintados con la paleta con que se emitieron los escapes — comportamiento estándar de terminales.
- `defaultLaunchTarget` sigue dormido; no se toca.

## Testing

- AppSettings nuevos campos: defaults, lectura persistida, persistencia en cambio, fallbacks (tema desconocido → Mocha; fuente inexistente → fallback monoespaciada) — espejo de AppSettingsTests existentes.
- TerminalTheme: 5 temas con exactamente 16 colores ANSI cada uno; lookup por id + fallback.
- TerminalAppearance: resolución de fuente con fallback; token de idempotencia cambia cuando cambia cualquier campo.
- DevtailTerminalView: copy-on-select copia al pasteboard cuando el flag está ON y no copia OFF (pasteboard de test con `releaseGlobally` como en AgentImagePasteTests); read-only sigue tragando input.
- Suite existente en verde: AppSettingsTests, WorkspaceSessionsHolderTests, ProcessSupervisorTests (+Reconfigure), mocks sin cambios.
