# Terminal appearance — Implementation Plan (Ciclo 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Terminal appearance (theme/font/cursor/behavior) configurable from a visual "Terminal" section in Settings, applied live to every terminal, with Javier's Ghostty config as defaults.

**Architecture:** `TerminalTheme` (5 built-in canonical palettes) + new persisted fields in `AppSettings` → resolved by a `TerminalAppearance` struct that knows how to apply itself to a SwiftTerm view. First paint happens in `SwiftTermSession.init` via an injected `appearanceProvider`; live re-apply happens in `TerminalHostView.updateNSView` (all terminals stay mounted, so no registry is needed). Behavior flags live on a new `DevtailTerminalView` base subclass (copy-on-select via `open selectionChanged`, mouse-hide via the `open send(source:data:)` choke point — `keyDown` is `public`, NOT `open`).

**Tech Stack:** Swift 6 (MainActor default), SwiftUI, SwiftTerm (vendored SPM), Swift Testing, UserDefaults.

**Spec:** `docs/superpowers/specs/2026-07-16-terminal-appearance-design.md`

## Global Constraints

- Código/comentarios/UI en inglés; conventional commits sin atribución de IA.
- Protocolos `TerminalEngine`/`TerminalSession` y `TerminalSessionConfig` NO cambian de firma pública consumida por mocks (`MockTerminalEngine` debe seguir compilando sin ediciones de contrato; si el engine real gana un parámetro de init con default, los mocks no se tocan).
- `ReadOnlyLocalProcessTerminalView` conserva su contrato EXACTO: `send(source:data:)` traga el input (no llama al envío de super).
- Protocolo OOM: un solo runner xcodebuild, `pgrep -f xcodebuild` antes de cada corrida, `-jobs 4`.
- Defaults exactos (config Ghostty de Javier): tema `catppuccin-mocha`, fuente `JetBrainsMono-Regular` talla 14, cursor block sin blink, copyOnSelect=true, hideMouseWhileTyping=true.
- SwiftTerm `installColors` exige EXACTAMENTE 16 `SwiftTerm.Color` con componentes de 16 bits (0–65535): convertir hex de 8 bits multiplicando por 257.
- Cursor style se setea en `getTerminal().setCursorStyle(_:)`, no en la vista.
- Las paletas de los 5 temas usan los valores canónicos publicados de cada proyecto (Catppuccin Mocha/Latte, Dracula, Solarized Dark, One Dark/Atom); Mocha es el default y sus valores están fijados en el Task 1.
- Suite base: 368 casos / 0 fallos sobre 76d30b4.

---

### Task 1: TerminalTheme + campos de AppSettings (TDD)

**Files:**
- Create: `Devtail/Features/Workspace/Models/TerminalTheme.swift`
- Modify: `Devtail/Core/Settings/AppSettings.swift`
- Test: `DevtailTests/Features/Workspace/TerminalThemeTests.swift` (nuevo), `DevtailTests/Core/Settings/AppSettingsTests.swift` (agregar casos)

**Interfaces:**
- Consumes: patrón `didSet`→UserDefaults existente en AppSettings (`agentCommand`).
- Produces: `struct TerminalTheme { let id: String; let name: String; let ansi: [ThemeColor]; let background/foreground/cursor/selection: ThemeColor }` con `struct ThemeColor { let red: UInt8; let green: UInt8; let blue: UInt8 }` (hex 8-bit; la conversión a 16-bit vive en el applier del Task 2); `static let builtIn: [TerminalTheme]`; `static func theme(id: String) -> TerminalTheme` (fallback Mocha). AppSettings: `terminalThemeId: String`, `terminalFontName: String`, `terminalFontSize: Double`, `terminalCursorBlock: Bool`, `terminalCursorBlinks: Bool`, `terminalCopyOnSelect: Bool`, `terminalHideMouseWhileTyping: Bool` — todos persistidos con `didSet`, leídos en init con esos defaults.

- [ ] **Step 1: Failing tests.** `TerminalThemeTests`: los 5 temas existen con ids `catppuccin-mocha`, `catppuccin-latte`, `dracula`, `solarized-dark`, `one-dark`; cada uno tiene EXACTAMENTE 16 colores ANSI; `theme(id: "unknown")` devuelve Mocha; `theme(id: "dracula").name == "Dracula"`. Mocha exacto (canónico): background `#1e1e2e`, foreground `#cdd6f4`, cursor `#f5e0dc`, selection `#585b70`, ansi = [`#45475a`,`#f38ba8`,`#a6e3a1`,`#f9e2af`,`#89b4fa`,`#f5c2e7`,`#94e2d5`,`#bac2de`,`#585b70`,`#f38ba8`,`#a6e3a1`,`#f9e2af`,`#89b4fa`,`#f5c2e7`,`#94e2d5`,`#a6adc8`] — testear background/foreground y ansi[1] (red) por valor. En `AppSettingsTests` (mismo estilo de suite existente con UserDefaults de test): defaults de los 7 campos nuevos (mocha/JetBrainsMono-Regular/14/true/false/true/true), lectura de valor persistido, persistencia en cambio (espejo de "agentCommand persists on change").
- [ ] **Step 2: Rojo.** Corrida focalizada — compile error / asserts fail.
- [ ] **Step 3: Implementación.** `TerminalTheme` con las 5 paletas canónicas embebidas (init de ThemeColor por hex: `init(hex: UInt32)`); AppSettings con los 7 campos patrón `didSet` (leer en init con `defaults.object(forKey:)` para distinguir ausencia en Bool/Double).
- [ ] **Step 4: Verde focalizado** (`TerminalThemeTests` + `AppSettingsTests` completo).
- [ ] **Step 5: Commit** `feat(settings): terminal themes and appearance settings model`

---

### Task 2: DevtailTerminalView + TerminalAppearance + primera pintura (TDD parcial)

**Files:**
- Create: `Devtail/Features/Workspace/Views/DevtailTerminalView.swift`
- Create: `Devtail/Features/Workspace/Services/TerminalAppearance.swift`
- Modify: `Devtail/Features/Workspace/Services/SwiftTermEngine.swift` (jerarquía + apply en init + appearanceProvider)
- Modify: `Devtail/Features/Workspace/Views/AgentTerminalView.swift` (extiende DevtailTerminalView)
- Modify: `Devtail/App/DevtailApp.swift` (cablear provider desde AppSettings)
- Test: `DevtailTests/Features/Workspace/DevtailTerminalViewTests.swift`, `DevtailTests/Features/Workspace/TerminalAppearanceTests.swift`

**Interfaces:**
- Consumes: `TerminalTheme.theme(id:)` y campos AppSettings del Task 1; APIs SwiftTerm: `font` (var), `installColors(_: [SwiftTerm.Color])`, `nativeBackgroundColor/nativeForegroundColor/caretColor/selectedTextBackgroundColor`, `getTerminal().setCursorStyle(_:)`, `CursorStyle.steadyBlock/.blinkBlock/.steadyBar/.blinkBar`.
- Produces: `struct TerminalAppearance: Equatable` con `init(settings: AppSettings)`, `static func resolveFont(name: String, size: Double) -> NSFont` (fallback: `NSFont(name:)` → `.monospacedSystemFont(ofSize:weight:.regular)`), `func apply(to view: TerminalView)`, y `var token: String` (identidad para el guard de idempotencia — deriva de todos los campos). `final class DevtailTerminalView: LocalProcessTerminalView` con `var copyOnSelect: Bool`, `var hideMouseWhileTyping: Bool` — OJO: no puede ser `final` porque ReadOnly/Agent la extienden; es `class`. `SwiftTermEngine.init(appearanceProvider: @MainActor @escaping () -> TerminalAppearance = { .fallback })` — default para no romper call sites de test.

- [ ] **Step 1: Failing tests.** `TerminalAppearanceTests`: resolveFont con nombre inexistente devuelve monoespaciada (chequear `isFixedPitch` del resultado o nombre != inexistente); token cambia al variar cada campo; token estable para settings iguales. `DevtailTerminalViewTests`: con `copyOnSelect=true` y selección activa simulada... (si simular selección de SwiftTerm resulta impracticable headless, testear el helper de decisión extraído `shouldCopy(selection: String?) -> Bool` y documentar; NO forzar un test vacuo). Read-only regression: los tests existentes de ProcessSupervisor ya cubren que el read-only traga input — mantener verdes.
- [ ] **Step 2: Rojo.**
- [ ] **Step 3: Implementación.**
  - `DevtailTerminalView`: override `selectionChanged(source:)` → `if copyOnSelect, let text = getSelection(), !text.isEmpty { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }` (llamar super primero). Override `send(source:data:)` → `if hideMouseWhileTyping { NSCursor.setHiddenUntilMouseMoves(true) }; super.send(source:data:)`.
  - Jerarquía: `ReadOnlyLocalProcessTerminalView: DevtailTerminalView` (su override de send que traga input QUEDA — no llama super, así que el mouse-hide no aplica en read-only: aceptable, no se tipea en read-only), `AgentTerminalView: DevtailTerminalView`, y el caso plano de `SwiftTermSession.init` construye `DevtailTerminalView(frame: .zero)`.
  - `TerminalAppearance.apply(to:)`: font, installColors (16 colores 16-bit: `UInt16(component) * 257`), colores nativos, cursor (`steadyBlock/blinkBlock/steadyBar/blinkBar` según los dos toggles), y si la vista es `DevtailTerminalView`, setear ambos flags.
  - `SwiftTermSession.init` aplica `engine.appearanceProvider()` a la vista recién creada (pasar el provider del engine a la sesión).
  - `DevtailApp`: construir `SwiftTermEngine { TerminalAppearance(settings: appSettings) }` donde hoy se construye el engine (localizar call site real — si el engine se crea dentro de WorkspaceSessionsHolder/ProcessSupervisor, inyectar el provider por ahí con default).
- [ ] **Step 4: Verde focalizado + suite completa** (mocks intactos).
- [ ] **Step 5: Commit** `feat(workspace): themed terminal view with first-paint appearance`

---

### Task 3: Reaplicación en vivo + padding y fondo del área

**Files:**
- Modify: `Devtail/Features/Workspace/Views/TerminalHostView.swift`
- Modify: `Devtail/Features/Workspace/Views/WorkspaceRootView.swift` (terminalArea)

**Interfaces:**
- Consumes: `TerminalAppearance(settings:)`, `.apply(to:)`, `.token`; `AppSettings` del environment (ya inyectado en la escena Workspace).
- Produces: re-apply en vivo en todas las terminales montadas; padding 12/8 con fondo del tema.

- [ ] **Step 1:** `TerminalHostView`: `@Environment(AppSettings.self)`; en `updateNSView`, construir `TerminalAppearance(settings:)` y aplicarla solo si `appearance.token` difiere del último aplicado (guardar el token en `Coordinator` — agregar coordinator si no existe; NO en @State). Cast a `TerminalView` de SwiftTerm.
- [ ] **Step 2:** `WorkspaceRootView.terminalArea`: envolver el ZStack con `.padding(.horizontal, 12).padding(.vertical, 8)` y `.background(themeBackgroundColor)` donde el color viene del tema activo (`TerminalTheme.theme(id: settings.terminalThemeId).background` → `Color(red:green:blue:)` /255). Leer AppSettings del environment del WorkspaceRootView. Los overlays existentes quedan dentro.
- [ ] **Step 3:** Build + suite focalizada de workspace. Expected: PASS.
- [ ] **Step 4: Commit** `feat(workspace): live appearance reapply and themed terminal frame`

---

### Task 4: Settings UI — sección Terminal visual

**Files:**
- Modify: `Devtail/Core/Settings/SettingsView.swift`
- Create: `Devtail/Core/Settings/TerminalThemePicker.swift` (fila de tema con swatches)
- Create: `Devtail/Core/Settings/MonospaceFontCatalog.swift` (enumeración de familias fixed-pitch vía NSFontManager/descriptores)
- Test: `DevtailTests/Core/Settings/MonospaceFontCatalogTests.swift` (catálogo no vacío en macOS, todos fixed-pitch; puro y testeable)

**Interfaces:**
- Consumes: campos AppSettings Task 1, `TerminalTheme.builtIn`.
- Produces: UI. `MonospaceFontCatalog.families() -> [String]` (nombres PostScript o family names — consistentes con lo que `NSFont(name:)` resuelve en TerminalAppearance.resolveFont).

- [ ] **Step 1:** `MonospaceFontCatalog` + test (familias con `NSFontTraitMask.fixedPitchFontMask` vía NSFontManager, orden alfabético, sin duplicados).
- [ ] **Step 2:** `TerminalThemePicker`: `ForEach(TerminalTheme.builtIn)` — fila clickeable: nombre + HStack de swatches (circulitos 12pt: background + ansi[1,2,3,4,5,6] representativos) + checkmark si seleccionado. Escribe `settings.terminalThemeId`.
- [ ] **Step 3:** `SettingsView`: `Section("Terminal")` con ThemePicker, `Picker` de fuente (cada opción `Text(name).font(.custom(name, size: 12))`), `Stepper(value: $settings.terminalFontSize, in: 10...20)`, toggles "Block cursor"/"Blink cursor"/"Copy on select"/"Hide mouse while typing". Frame de la ventana 420→480.
- [ ] **Step 4:** Build + suite completa. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): visual terminal appearance section`

---

### Task 5: Suite final + ledger + review de branch

- [ ] **Step 1:** `pgrep -f xcodebuild`; suite completa `-jobs 4`. Expected: 0 fallos; anotar conteo.
- [ ] **Step 2:** Ledger `.superpowers/sdd/progress.md` (Ciclo 6, no se commitea).
- [ ] **Step 3:** Review final de branch (cross-task) + fix wave si aplica + re-review.
- [ ] **Step 4:** `>>> PENDIENTE: USER CHECKPOINT (Javier)`: Settings→Terminal visible con swatches; cambiar tema y ver TODAS las terminales repintarse en vivo; JetBrains Mono 14 por default; cursor block sin blink; seleccionar texto copia al clipboard; el mouse se oculta al tipear; padding 12/8 con marco del color del tema.
