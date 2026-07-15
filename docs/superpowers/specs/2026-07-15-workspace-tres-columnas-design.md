# Workspace de tres columnas y hub delgado (Ciclo 1)

## Contexto y decisión

Devtail v1 dejó la ventana de workspace con dos paneles (terminal + sidebar de
procesos) y un dashboard-hub que concentra todo el detalle del proyecto. La
visión de Javier (2026-07-15) es la cabina que intentaba en Estación
(DevStation): ventana por proyecto con **dashboard | terminal | file tree**, y
una ventana hub delgada estilo JetBrains/VSCode para abrir y crear proyectos.

Decisiones cerradas en brainstorming:

- **Modelo JetBrains**: se descartó la ventana única unificada. Queda ventana
  hub (welcome) + una ventana de workspace por proyecto. Coincide con el
  modelo de dos ventanas que Devtail ya tiene; no hay rearquitectura de
  escenas ni de ciclo de vida de sesiones.
- **Hub delgado**: todo el estado vivo (procesos, git, quick links, sesión) se
  muda a la columna dashboard del workspace. El hub queda como welcome: lista,
  búsqueda, crear/editar/eliminar, Launch/Resume. Una sola fuente de verdad
  por dato.
- **La visión completa se ejecuta en ciclos**: Ciclo 1 (este) = layout de tres
  columnas + hub delgado, con placeholder del tree. Ciclo 2 = file tree lazy +
  visor embebido read-only con syntax highlighting (paridad Estación; el click
  en archivo abre tab en el centro — decidido sobre la alternativa de abrir en
  VSCode). Ciclo 3 = agente Claude en pane + imágenes vía bracketed paste
  (diferido explícitamente; se monta sobre las columnas cuando existan).
- **Lados invertidos respecto a Estación**: allá el tree era izquierda y el
  dashboard derecha; en Devtail el dashboard va a la izquierda y el tree a la
  derecha, por decisión de Javier.

## Arquitectura

### Layout de la ventana workspace

`WorkspaceRootView` pasa de `HSplitView` de dos paneles a tres columnas:

- **Izquierda — dashboard del proyecto**: 260–340pt, redimensionable.
- **Centro — terminal**: `minWidth` 640, sin cambios internos. La tab row, el
  `ZStack` de retención con `opacity`/`allowsHitTesting`, el
  `deadShellOverlay` y todo el motor de terminal/procesos quedan intactos.
- **Derecha — placeholder del tree**: 220–300pt, con un estado vacío estable
  ("Files — próximamente") para que el Ciclo 2 nazca dentro de una columna ya
  existente, sin reestructurar el layout otra vez.

### Columna dashboard (izquierda)

Stack scrolleable de cards. Se compone de lo que hoy vive en el sidebar
derecho más lo que baja del hub:

- **Header del proyecto**: nombre, path, dot de actividad.
- **Git**: branch actual, ya detectada por la sesión (mismo dato que hoy
  muestra el sidebar).
- **Procesos**: las `ProcessCardView` actuales movidas tal cual, con su
  contrato start/stop/restart intacto.
- **Quick links**: panel de visualización y apertura (la edición NO vive
  acá).
- **Sesión**: card nueva con el tiempo transcurrido desde la apertura del
  workspace. Única pieza sin equivalente actual; reloj barato derivado de un
  timestamp de apertura en la sesión.

### Hub delgado

`DashboardDetailView` se reduce a welcome estilo JetBrains:

- **Queda**: hero (nombre, path, resumen de layout, last seen), botones
  Launch/Resume (con su confirmación de cambio de branch), menú
  editar/eliminar, apertura en VSCode.
- **Se va**: el `WorkspaceLayoutPicker` interactivo del modo browsing, el
  thumbnail con menús por slot y el `QuickLinksPanel` de visualización.
- **La edición se concentra en `ProjectFormView`** (crear/editar): layout,
  panes/procesos y quick links se editan ahí y solo ahí. El estado vivo se
  consulta en la columna dashboard del workspace.

El sidebar del hub, el menu bar y sus flujos (`openWindow`, intents de
crear/editar) no cambian.

### Datos y sesiones

Sin cambios de semántica: ventana por proyecto, `WorkspaceSessionsHolder`
sigue siendo dueño de las sesiones y del teardown en `onDisappear`/quit. La
columna dashboard lee los mismos objetos (`WorkspaceSession`,
`ProcessSupervisor`, branch, quick-link snapshots) que hoy lee el sidebar
derecho. Cero migración de SwiftData; las columnas dormidas (`layoutSlot`,
`layout`, `launchTarget`) siguen dormidas.

## Testing

- La suite actual (283) debe seguir verde: los componentes se mueven de
  contenedor, no cambian de contrato.
- Tests nuevos: timestamp/derivación del reloj de sesión; y los tests del hub
  que pierdan anclaje por el adelgazamiento se reubican hacia el form o la
  columna dashboard según dónde quede la responsabilidad.
- Checkpoint manual de Javier al final (como en v1): tres columnas operativas,
  procesos y quick links funcionando desde la columna izquierda, hub delgado
  con Launch/Resume intactos.

## Fuera de alcance (ciclos siguientes)

- **Ciclo 2**: file tree lazy (recursivo custom con `DisclosureGroup`, carga
  de hijos al expandir), visor read-only como tabs del centro (sin retención
  ZStack — no hay PTY que preservar) y highlighting vía Highlightr (SPM;
  decidido sobre tree-sitter por costo/beneficio en un visor read-only).
- **Ciclo 3**: agente Claude en pane (auto-launch, resume) + imágenes vía
  bracketed paste (`\x1b[200~ruta\x1b[201~` → `[Image #N]`, mecanismo ya
  verificado en Estación).
- Hardening diferido del v1 (SIGKILL en quit, `.error` state en spawn
  fallido, test `./x`-prefix) sigue pendiente y no entra en este ciclo.
