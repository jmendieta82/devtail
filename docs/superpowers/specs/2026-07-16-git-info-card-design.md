# Git card enriquecida — feature 1 del panel de información

**Fecha**: 2026-07-16 · **Aprobado por**: Javier

## Problema

La card "Branch" del panel derecho solo muestra la rama activa (detectada leyendo `.git/HEAD`, sin shell). Javier quiere más contexto git: cuántas ramas hay, cuál está activa, y si hay commits pendientes (sin commitear / sin pushear).

## Diseño

### GitStatusReader — primer helper de captura de stdout

No existe wrapper de `Process` que capture salida (todo es PTY/NSWorkspace). Se crea `GitStatusReader` (Core/GitDetection/):

- `func status(in root: URL) -> GitStatus?` — corre git vía `Foundation.Process` (sandbox OFF lo permite) y devuelve un struct, o nil si no es repo git.
- Comandos (un solo Process por dato, `/usr/bin/git -C <root> ...`, timeout corto, stdout capturado):
  - `git rev-parse --abbrev-ref HEAD` → rama activa (o "HEAD" si detached).
  - `git branch --format=%(refname:short)` → conteo de ramas locales.
  - `git status --porcelain` → líneas = archivos con cambios (dirty si no vacío).
  - `git rev-list --count --left-right @{upstream}...HEAD` → ahead/behind (si hay upstream; nil si no).
- `struct GitStatus { let branch: String; let localBranchCount: Int; let isDirty: Bool; let changedFileCount: Int; let ahead: Int?; let behind: Int? }`.
- **El PARSEO de cada salida se extrae a funciones puras estáticas testeables** (`parseAheadBehind`, `parseBranchCount`, `parsePorcelain`) — el Process en sí no se testea headless; los parsers sí, con TDD.

### Ejecución async

Correr 4 comandos git es I/O — no puede bloquear el MainActor. `WorkspaceSession` gana `var gitStatus: GitStatus?` (observable, opcional), cargado en un `Task` disparado al abrir el workspace (junto a la detección de branch actual) y refrescable. El detector de branch por-archivo (`.git/HEAD`) se conserva para el arranque instantáneo; `gitStatus` lo enriquece cuando llega.

### Card enriquecida

`branchSection` pasa a mostrar (cuando hay `gitStatus`):
- Rama activa con su ícono (como hoy).
- **Ramas**: "N branches" (conteo local).
- **Estado**: "Clean" (verde) o "N uncommitted" (ámbar) según dirty.
- **Sync**: "↑N ↓M" ahead/behind si hay upstream; oculto si no.
- Botón de refresh (icono, `.buttonStyle(.icon)`) que re-dispara el Task.

Fallback: si `gitStatus == nil` pero `currentBranch != nil` (repo sin poder correr git, o mientras carga), muestra solo la rama como hoy — nunca peor que el estado actual.

## Límites aceptados

- El estado es una foto al abrir + refresh manual; no hay watcher de FS (editás afuera → tocás refresh).
- Ramas remotas no se cuentan (solo locales) en v1.

## Testing

- Parsers puros (TDD): `parseAheadBehind("2\t5")` → (behind 2, ahead 5); porcelain vacío → clean, con líneas → count; branch count por líneas.
- Suite existente en verde (GitBranchDetector/RemoteDetector/SessionClock intactos).
- `GitStatusReader.status` end-to-end es best-effort manual (corre git real) — documentar.
