# File tree y visor embebido (Ciclo 2)

## Contexto y decisión

Ciclo 2 de la visión "workspace 3 columnas" (ver spec del Ciclo 1,
2026-07-15-workspace-tres-columnas-design.md, mergeado en 00d941e). La columna
derecha deja de ser placeholder: file tree lazy del proyecto, cuyo click en
archivo abre un visor read-only con syntax highlighting como tab del centro,
junto a las tabs de terminal/procesos. Paridad con lo validado en Estación.

Decisiones cerradas en diseño (2026-07-15, aprobadas por Javier):

- **Motor de highlighting: HighlighterSwift** (smittytone), NO Highlightr como
  decía el spec del Ciclo 1 — Highlightr se autodeclara sin mantenimiento
  desde 2026 y redirige a este fork (verificado: activo, SPM `Highlighter`,
  macOS 11+, highlight.js 11.11.1, ~192 lenguajes, tema `material-palenight`
  incluido, `Theme.themeBackgroundColour` programático). API casi idéntica.
- **Concurrency**: ni el fork ni el original modelan Swift 6 (JSContext no es
  Sendable). La instancia se confina a `@MainActor` en un servicio propio; el
  costo por archivo se acota con guardrails, no con off-main hops.
- **Guardrails estilo VS Code**: archivo > 512 KB o > 10.000 líneas → texto
  plano sin highlight; > 5 MB → placeholder "File too large"; binario
  (NUL en los primeros 8 KB) → placeholder "Binary file".
- **Selección de tabs**: `selectedTab: UUID?` (nil = terminal) no alcanza para
  tres especies de tab. Se migra a
  `enum WorkspaceTab: Hashable { case terminal; case process(UUID); case file(String) }`
  (el `String` es el path absoluto del archivo).
- **Tabs de archivo sin retención ZStack**: no hay PTY que preservar; se
  renderiza solo la tab de archivo seleccionada. El scroll se resetea al
  cambiar de tab — aceptable en v1. La retención ZStack de terminales queda
  INTACTA.
- **Números de línea con gutter `NSRulerView`**, no el numerado integrado de
  HighlighterSwift (hornea los números dentro del texto: se copiarían junto
  con el código).
- **Dotfiles visibles pero atenuados** (patrón Estación). Sin badges de git en
  el tree (fuera de alcance, igual que en Estación).
- **Sin búsqueda in-file** en este ciclo (Cmd+F del visor de Estación queda
  para más adelante).

## Arquitectura

### Modelo de selección y archivos abiertos

`WorkspaceTab` (enum nuevo en Features/Workspace/Models). `WorkspaceSession`
migra `selectedTab` a `WorkspaceTab` (default `.terminal`) y gana:

- `openFiles: [OpenFile]` — struct `Identifiable/Hashable`, id = path.
- `openFile(at path: String)`: idempotente — si ya está abierto solo lo
  selecciona; si no, lo agrega al final y lo selecciona.
- `closeFile(at path: String)`: lo quita; si era la tab seleccionada,
  selecciona la tab de archivo vecina (anterior, si no siguiente) o
  `.terminal` si no quedan archivos; si no era la seleccionada, la selección
  no cambia.

El estado vive en la sesión (dueño: `WorkspaceSessionsHolder`) — sobrevive a
cambios de tab y de proyecto visible, muere con la sesión.

### File tree (columna derecha)

- **`DirectoryLister` (protocolo)** + `FileManagerDirectoryLister`: primer
  seam de FileManager del codebase (hoy no existe abstracción). Lista un
  directorio (nombre, URL, esDirectorio), incluye ocultos, orden
  carpetas-primero + alfabético case-insensitive.
- **`FileTreeStore` (@Observable)**, dueño: la sesión (el estado de expansión
  sobrevive). Nodos lazy: hijos se cargan en el primer expand, error por nodo
  (no global). Defensas heredadas del incidente GitBranchDetector: guard de
  path absoluto, cap de profundidad (32), corte en punto fijo. Los hijos
  cargados se cachean (colapsar/re-expandir NO re-lista); sin refresh ni
  FSEvents/watching en v1 — el tree refleja el disco al momento de expandir.
- **`FileTreeColumn`** reemplaza a `FileTreePlaceholderColumn`: filas
  recursivas con indentación, triángulo de disclosure, icono carpeta/archivo,
  dotfiles con opacidad reducida. Click en archivo → `session.openFile`.

### Visor (tabs del centro)

- **`CodeLanguageMap`**: mapa puro extensión → lenguaje highlight.js;
  extensión desconocida → nil (auto-detect del motor).
- **`FileContentLoader`**: función pura de carga con los guardrails (binario /
  demasiado grande / texto plano grande / texto highlighteable).
- **`CodeHighlighter` (@MainActor)**: envuelve `Highlighter` (lazy), tema
  `material-palenight` con fuente UbuntuMono-Regular 13 (tokens del
  DesignSystem), `doFastRender: true`. Fondo del visor =
  `theme.themeBackgroundColour`.
- **`CodeViewerView`**: `NSViewRepresentable` sobre `NSTextView` read-only
  (TextKit; SwiftUI `Text` no escala a miles de líneas) dentro de
  `NSScrollView` con `LineNumberRulerView: NSRulerView` como gutter.
- **`FileViewerTabView`**: estados carga → contenido (highlighted / plano /
  binario / grande / error de lectura), carga vía `.task`.

`WorkspaceRootView`: `tabRow` suma tabs de archivo (nombre + botón ✕);
el área central muestra el visor cuando `selectedTab` es `.file`, con los
terminales del ZStack simplemente ocultos como hasta ahora (su retención no
cambia).

## Testing

- TDD en stores y funciones puras: `WorkspaceTab`/open-close de archivos
  (selección vecina), `FileTreeStore` (lister mock + integración con temp
  dirs, patrón `temporaryDirectory + UUID + defer removeItem` existente),
  `CodeLanguageMap`, guardrails de `FileContentLoader` (binario, tamaños).
- Un smoke test de `CodeHighlighter` (highlight de un snippet Swift ≠ nil).
- Migración de `selectedTab`: los tests existentes que lo referencien se
  actualizan al enum.
- Vistas (tree, viewer, tabs): compile + checkpoint manual de Javier.
- Suite base a preservar: 288 casos, 0 fallos.

## Fuera de alcance

- Ciclo 3: agente Claude en pane + imágenes (bracketed paste).
- Búsqueda in-file (Cmd+F), badges git en el tree, file watching (FSEvents),
  retención de scroll en tabs de archivo, edición de archivos.
