#!/bin/bash
#
# Build Devtail in Release and install it into /Applications.
#
# The awkward part: the app being replaced is usually the one hosting the
# Claude agent that runs this script. So the swap cannot happen inline — it is
# handed to a detached watcher that waits for Devtail to quit, replaces the
# bundle, relaunches it once, and deletes itself.
#
#   ./scripts/install.sh            build, then watch-and-swap
#   ./scripts/install.sh --build    build only, print the artifact path
#   ./scripts/install.sh --now      swap immediately (app must NOT be running)
#
# Log: $TMPDIR/devtail-install.log

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="/Applications/Devtail.app"
LOG="${TMPDIR:-/tmp}/devtail-install.log"
BUILD_DIR="${TMPDIR:-/tmp}/devtail-release-build"
ARTIFACT="$BUILD_DIR/Build/Products/Release/Devtail.app"
WATCHER="${TMPDIR:-/tmp}/devtail-install-watcher-$$.sh"

MODE="${1:-watch}"

die() { echo "error: $*" >&2; exit 1; }

build() {
    echo "Building Release…"
    xcodebuild -project "$REPO_ROOT/Devtail.xcodeproj" -scheme Devtail \
        -configuration Release -derivedDataPath "$BUILD_DIR" build \
        > "${TMPDIR:-/tmp}/devtail-build.log" 2>&1 \
        || { tail -30 "${TMPDIR:-/tmp}/devtail-build.log"; die "build failed"; }

    [[ -d "$ARTIFACT" ]] || die "build succeeded but no bundle at $ARTIFACT"

    # Verify the two project invariants on the real binary rather than trusting
    # the build settings: Hardened Runtime must be on, App Sandbox must be off.
    # A silent re-sandbox already happened once (2026-07-15) and broke PTYs.
    local flags
    flags="$(codesign -dv --verbose=2 "$ARTIFACT" 2>&1 | rg -o 'flags=0x[0-9a-f]+\([a-z,]+\)' || true)"
    [[ "$flags" == *runtime* ]] || die "Hardened Runtime is OFF ($flags) — refusing to install"

    if codesign -d --entitlements - "$ARTIFACT" 2>/dev/null | rg -qi 'app-sandbox'; then
        die "App Sandbox entitlement present — refusing to install (see CLAUDE.md decision 1)"
    fi

    echo "Built and verified: $ARTIFACT"
}

swap() {
    rm -rf "$TARGET"
    ditto "$ARTIFACT" "$TARGET"
}

case "$MODE" in
    --build)
        build
        echo "$ARTIFACT"
        ;;

    --now)
        build
        pgrep -x Devtail >/dev/null && die "Devtail is running — quit it first, or use the default watch mode"
        swap
        echo "Installed to $TARGET (not launched)"
        ;;

    watch)
        build

        # Refuse to arm a watcher with nothing to wait for: in that state it
        # would swap instantly, which is --now's job and should be explicit.
        pgrep -x Devtail >/dev/null \
            || die "Devtail is not running — nothing to wait for. Use --now to install directly."

        # The watcher is generated per-run and self-deletes. Two guards against
        # the 2026-07-24 relaunch loop, when a resident watcher reopened the app
        # on every quit and made Devtail impossible to close:
        #   1. the relaunch is a single call outside any loop
        #   2. the script rm's itself before exiting, so no copy can fire twice
        cat > "$WATCHER" <<WATCHER_EOF
#!/bin/bash
set -euo pipefail
exec >>"$LOG" 2>&1
echo "=== watcher started \$(date) ==="

deadline=\$((SECONDS + 120))
while pgrep -x Devtail >/dev/null; do
    if (( SECONDS > deadline )); then
        echo "timeout: still running after 120s — aborting swap, /Applications untouched"
        rm -f "$WATCHER"
        exit 1
    fi
    sleep 1
done

echo "Devtail exited, swapping bundle"
rm -rf "$TARGET"
ditto "$ARTIFACT" "$TARGET"
echo "swapped, relaunching"
open "$TARGET"
echo "=== done, watcher removing itself ==="
rm -f "$WATCHER"
WATCHER_EOF
        chmod +x "$WATCHER"

        nohup setsid "$WATCHER" >/dev/null 2>&1 </dev/null &
        disown 2>/dev/null || true

        # Detached launches have failed silently before, leaving no watcher and
        # no log. Confirm it is actually alive before telling the user to quit.
        sleep 1
        if ! pgrep -f "$(basename "$WATCHER")" >/dev/null; then
            rm -f "$WATCHER"
            die "watcher failed to start — nothing is armed. Quit Devtail and run: $0 --now"
        fi

        echo "Watcher armed. Quit Devtail (⌘Q) — it will be replaced and relaunched."
        echo "Log: $LOG"
        ;;

    *)
        die "unknown mode '$MODE' (expected --build, --now, or no argument)"
        ;;
esac
