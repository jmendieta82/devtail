# Introspección de Claude Code — feature 3 del panel de información

**Fecha**: 2026-07-16 · **Aprobado por**: Javier

## Problema

El panel derecho no muestra nada sobre la configuración de Claude Code del proyecto. Javier quiere ver, de un vistazo, qué skills / MCP servers / slash commands / agents hay instalados, y los tokens consumidos.

## Formatos (verificados en disco)

- **Skills**: `SKILL.md` en `<root>/.claude/skills/*/SKILL.md` (proyecto) y `~/.claude/skills/*/SKILL.md` (global). Frontmatter YAML con `name`, `description`.
- **Agents**: `<root>/.claude/agents/*.md` y `~/.claude/agents/*.md`. Frontmatter con `name`/`description` (o el filename como fallback).
- **Commands**: `<root>/.claude/commands/*.md` y `~/.claude/commands/*.md`. El nombre es el filename (`sdd-apply.md` → `/sdd-apply`).
- **MCP servers**: `~/.claude.json` → `mcpServers` (global) + `projects["<root>"].mcpServers` (por-proyecto); más `<root>/.mcp.json` (`mcpServers`) si existe. Unión deduplicada por nombre.
- **Tokens**: `~/.claude/projects/<encoded-root>/*.jsonl`, donde `<encoded-root>` = el path absoluto con `/` → `-`. Cada línea JSON puede traer `message.usage` con `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`. Suma total = input+output+cache de todas las líneas de todos los transcripts del proyecto.

## Diseño

### ClaudeProjectIntrospector (Core/Claude/)

`func introspect(projectRoot: URL, home: URL) -> ClaudeIntrospection` — best-effort, nunca throwea; cada sección faltante queda vacía. `home` inyectable para tests.

- `struct ClaudeIntrospection { let skills: [ClaudeItem]; let agents: [ClaudeItem]; let commands: [ClaudeItem]; let mcpServers: [String]; let tokenUsage: TokenUsage? }`
- `struct ClaudeItem { let name: String; let detail: String?; let scope: Scope }` (`Scope`: `.project` / `.global`).
- `struct TokenUsage { let input: Int; let output: Int; let cache: Int; var total: Int }`.

**Piezas puras extraídas (TDD)**:
- `FrontmatterParser.parse(_ markdown: String) -> [String: String]` — lee el bloque `---\n...\n---` inicial, claves simples `key: value` (quita comillas). No es un parser YAML completo — solo lo necesario.
- `ClaudePathEncoder.encode(_ path: String) -> String` — `/Volumes/.../DarSoluciones` → `-Volumes-...-DarSoluciones`.
- `TokenAggregator.sum(jsonlLines: [String]) -> TokenUsage` — parsea cada línea, extrae `message.usage` (o `usage` top-level), acumula; ignora líneas sin usage o inválidas.
- `MCPMerger.merge(global: [String], project: [String]) -> [String]` — unión ordenada dedup.

La lectura de disco (enumerar directorios, leer archivos, listar transcripts) vive en el introspector; los parsers son puros.

### Carga y card

`WorkspaceSession` gana `var claudeInfo: ClaudeIntrospection?`, cargado en un `Task` cancelable (mismo patrón que `gitStatus`: seam + cancel en `close`). Nueva `claudeSection` en `WorkspaceDashboardColumn`, después de `sessionSection`:

- Card titulada "Claude". Filas compactas con conteo por categoría e ícono: "N skills", "N agents", "N commands", "N MCP servers", y "N tokens" (formateado 1.2M / 340k) si hay usage.
- Cada categoría con conteo > 0 es expandible (disclosure) para ver la lista de nombres; scope global vs proyecto con un matiz (ej. punto o sufijo). MVP: mostrar conteos siempre, expandir para nombres.
- Refresh (icono) que re-dispara el Task.
- Si todo vacío (proyecto sin `.claude`): la card muestra "No Claude config" en vez de esconderse — señal útil.

## Límites aceptados

- Frontmatter parser es minimalista (key: value de una línea) — descripciones multilinea se truncan a la primera línea; suficiente para el nombre/descripción de skills.
- Tokens son el acumulado histórico de TODOS los transcripts del proyecto (no de "esta sesión") — se etiqueta "Total tokens".
- Sin watcher: refresh manual.

## Testing

- `FrontmatterParser` (TDD): bloque válido, sin frontmatter, comillas, clave ausente.
- `ClaudePathEncoder`: path normal, con espacios, trailing slash.
- `TokenAggregator`: líneas con usage suma correcta, líneas sin usage ignoradas, JSON inválido ignorado, vacío → ceros.
- `MCPMerger`: dedup, orden, uno vacío.
- `ClaudeProjectIntrospector` end-to-end con un `home`/root temporal (crear `.claude/skills/x/SKILL.md` etc. en un tmpdir) — testeable sin mocks.
- Card wiring: default nil, seam + cancel como gitStatus.
- Suite existente en verde.
