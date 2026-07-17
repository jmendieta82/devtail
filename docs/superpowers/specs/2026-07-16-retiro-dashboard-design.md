# Retiro del dashboard — Ciclo 7

**Fecha**: 2026-07-16 · **Aprobado por**: Javier ("esta ventana ya no tiene sentido… pero sí me gusta su color con gradiente")

## Problema

Tras C5 (edición → workspace) y C6 (app settings → settings tab), la ventana del dashboard quedó como navegador read-only que duplica al popover. Se retira. El gradiente que le gusta a Javier **ya existe idéntico en el popover** (`MenuBarRootView.popoverBackground` = mismos 3 stops y diagonal que `DashboardRootView.dashboardBackground`) — se conserva.

## Decisiones (aprobadas)

1. **Create → ventana mínima "New Project"**: los sheets de panes del form exigen 560pt (> popover 400). Ventana dedicada (~680×620, gradiente, `ProjectFormView(projectID: nil)`), abierta desde el "New project" del popover (footer + empty state) y **Cmd+N**. `onDismiss` del form la cierra (`\.dismiss`). El dirty-guard de create del dashboard muere con el dashboard (cerrar la ventana descarta, comportamiento estándar de ventana).
2. **Delete y VSCode → context menu de la fila del popover**: "Open in VSCode" (`store.openInVSCode`) y "Delete project…" con `confirmationDialog` → `store.deleteProject`.
3. **Resume → fila expandida del popover**: cuando `project.lastLaunchedAt != nil`, botón Resume junto a Launch, con la detección de branch (`store.detectBranchChanges` + alert Continue/Cancel) portada de `DashboardDetailView.handleResumeTap` — misma semántica.
4. **Sort → header del popover**: menú compacto reciente/alfabético reutilizando `SidebarSortMode` y su persistencia (se muda de DashboardRootView al popover).
5. **Se descarta sin reemplazo**: "View details" read-only y el link "View in Dashboard…".
6. **Se borra**: escena dashboard + `WindowID.dashboard`, `DashboardRootView`, `DashboardDetailView`, `DashboardSidebarItem`, `DashboardIntentHolder`/`DashboardIntent` (los entry points abren la ventana de create directo, sin intents), Cmd+N repunteado.

## Límites aceptados

- Cerrar la ventana New Project con el form a medias descarta silenciosamente (es una ventana; Cancel/cierre = descartar, sin diálogo).
- El VSCode con ícono real de LaunchServices vive ahora solo en el context menu del popover.

## Testing

- Suite existente en verde (no hay tests de las vistas retiradas; `ProjectFormAutosaveTests` no se toca).
- Piezas puras que se muevan (sort, decisión de resume) conservan/ganan tests donde ya exista patrón.
- Sweep de huérfanos: cero referencias a `Dashboard*`/`WindowID.dashboard`/intents.
