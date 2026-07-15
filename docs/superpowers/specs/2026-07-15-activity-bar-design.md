# Activity bar y panel conmutable (Ciclo 4)

## Contexto y decisión

Con el Ciclo 3 mergeado (92b5f21, modelo de tabs efímeras), Javier pidió la
convergencia final al layout Estación/VS Code: un **rail de iconos**
(activity bar) a la izquierda que conmuta qué muestra el panel adyacente, y
la información general del proyecto (dashboard) mudada a la **derecha**.

Decisiones cerradas (2026-07-15, con Javier):

- **Vistas iniciales del rail: dos** — Archivos (tree) y Procesos (opción A).
  Search/git/docker se suman en ciclos futuros sobre la misma estructura.
- **Swap de columnas**: izquierda = rail (48pt fijo) + panel conmutable
  (220–300, redimensionable); derecha = dashboard (header, branch, quick
  links, sesión — SIN procesos, que se mudan al panel). Centro intacto.
- **Sin colapso del panel en v1** (diferido); sin persistencia de la vista
  seleccionada entre sesiones (estado en memoria de la sesión, default
  Archivos).

## Arquitectura

- `enum SidePanelView: CaseIterable { case files, processes }` con icono
  SF Symbol y tooltip por caso.
- `WorkspaceSession.sidePanel: SidePanelView = .files` (estado en memoria,
  vive con la sesión como la expansión del tree).
- **`ActivityBar`**: columna vertical de botones-icono (48pt), estado
  seleccionado con `DevtailTokens.Colors.accentPrimary`, tooltip `.help`.
- **`WorkspaceSidePanel`**: switch sobre `session.sidePanel` — `.files` →
  contenido actual de `FileTreeColumn`; `.processes` → sección de procesos
  (SectionHeader + `ProcessCardView` con sus closures actuales) EXTRAÍDA de
  `WorkspaceDashboardColumn`.
- **`WorkspaceDashboardColumn`** (derecha ahora): pierde la sección de
  procesos; conserva header, branch, quick links y reloj de sesión.
- **`WorkspaceRootView`**: `HSplitView { HStack(spacing:0){ ActivityBar;
  WorkspaceSidePanel } (min 48+220) | centro (min 640) | dashboard
  (260–340) }`. Nada del centro (tabs/ZStack/retención) cambia.

## Testing

- TDD mínimo de estado: default `.files`, switching (trivial, en holder
  tests o suite propia).
- Vistas: compile + checkpoint manual (rail conmuta, procesos operables
  desde el panel, tree intacto con expansión sobreviviendo al switch,
  dashboard a la derecha completo).
- Suite base a preservar: la actual en main (0 fallos).

## Fuera de alcance

- Colapso del panel, persistencia de la vista, vistas search/git/docker,
  drag para reordenar iconos.
