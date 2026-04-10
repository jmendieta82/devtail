-- smoke-quarters.applescript
--
-- T0 GATE — Quarters Non-Sequential Split Smoke Test
-- ===================================================
-- PURPOSE:
--   Verify that Ghostty's AppleScript dictionary supports non-sequential
--   binary splits. Specifically: after splitting term0 RIGHT to produce
--   term1, can we still split term0 DOWN to produce term2 (bottom-left)?
--   If yes → the Quarters layout in Devtail is feasible.
--   If no  → stop the entire magnet-visual-layout-picker change.
--
-- SPLIT SEQUENCE (mirrors design §2 Quarters splitSequence):
--   term0 = initial window (top-left anchor)
--   term1 = split term0 right  → term0 becomes top-left, term1 is top-right
--   term2 = split term0 down   → term0 stays top-left, term2 is bottom-left
--             ↑ CRITICAL: source is term0, NOT term1
--   term3 = split term1 down   → term1 stays top-right, term3 is bottom-right
--
-- EXPECTED RESULT (visual 2x2 grid):
--   +---------------------+---------------------+
--   | === SLOT 0: TOP-LEFT ===                   |
--   |                     | === SLOT 1: TOP-RIGHT === |
--   +---------------------+---------------------+
--   | === SLOT 2: BOTTOM-LEFT ===               |
--   |                     | === SLOT 3: BOTTOM-RIGHT === |
--   +---------------------+---------------------+
--
-- HOW TO RUN (from project root):
--   osascript scripts/smoke-quarters.applescript
--
-- PASS: Ghostty opens with exactly 4 panes in a 2x2 grid.
--       Each pane shows its unique label in the correct quadrant.
-- FAIL: Error from osascript (Ghostty rejected a split), OR the 4 panes
--       appear in a 1x4 chain instead of a 2x2 grid, OR labels are in the
--       wrong quadrant.
--
-- If this test FAILS → do NOT proceed with sdd-apply. Report back to the
-- orchestrator to revisit the design (see design §5.6 failure modes).

tell application "Ghostty"
    activate

    -- SLOT 0: Open initial window pointing at /tmp (neutral path)
    set cfg0 to new surface configuration
    set initial working directory of cfg0 to "/tmp"
    set win to new window with configuration cfg0
    set term0 to focused terminal of selected tab of win

    -- Small delay to let the window settle before driving it
    delay 0.5

    -- SLOT 1: Split term0 RIGHT → top-right quadrant
    set cfg1 to new surface configuration
    set initial working directory of cfg1 to "/tmp"
    set term1 to split term0 direction right with configuration cfg1

    -- SLOT 2: Split term0 DOWN → bottom-left quadrant
    --         SOURCE = term0, not term1. This is the non-sequential test.
    set cfg2 to new surface configuration
    set initial working directory of cfg2 to "/tmp"
    set term2 to split term0 direction down with configuration cfg2

    -- SLOT 3: Split term1 DOWN → bottom-right quadrant
    --         SOURCE = term1 (not term2).
    set cfg3 to new surface configuration
    set initial working directory of cfg3 to "/tmp"
    set term3 to split term1 direction down with configuration cfg3

    -- Send unique labels to each pane so you can visually confirm position.
    -- Panes are driven in reverse order to avoid focus confusion (term3 is
    -- the most recently focused; we work back to term0).
    input text "echo \"=== SLOT 3: BOTTOM-RIGHT ===\"" to term3
    send key "enter" to term3

    input text "echo \"=== SLOT 2: BOTTOM-LEFT ===\"" to term2
    send key "enter" to term2

    input text "echo \"=== SLOT 1: TOP-RIGHT ===\"" to term1
    send key "enter" to term1

    input text "echo \"=== SLOT 0: TOP-LEFT ===\"" to term0
    send key "enter" to term0

    -- Return focus to slot 0 (top-left anchor) — matches Devtail launcher behavior
    focus term0

end tell
