#!/bin/bash
# Wallpaper Engine KDE Plugin - Uninstaller

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERR ]${NC} $*" >&2; }
die()   { error "$*"; exit 1; }

PLUGIN_ID="com.github.catsout.wallpaperEngineKde"
QML_SYSTEM_DIR="/usr/lib/qt6/qml/com/github/catsout/wallpaperEngineKde"
QML_SYSTEM_DIR_ALT="/usr/lib/qt5/qml/com/github/catsout/wallpaperEngineKde"
PLASMA_USER_DIR="${HOME}/.local/share/plasma/wallpapers/${PLUGIN_ID}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Wallpaper Engine KDE Plugin – Uninstaller"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Parse flags
SKIP_RESTART=0
YES=0
for arg in "$@"; do
    case "$arg" in
        --skip-restart) SKIP_RESTART=1 ;;
        --yes|-y)       YES=1 ;;
        --help|-h)
            echo "Usage: $0 [--yes] [--skip-restart]"
            echo ""
            echo "  --yes / -y      Skip confirmation prompt"
            echo "  --skip-restart  Skip restarting plasmashell after uninstall"
            exit 0
            ;;
    esac
done

# ── confirm ───────────────────────────────────────────────────────────────────
if [[ "${YES}" == "0" ]]; then
    echo "This will remove:"
    echo "  [system]  ${QML_SYSTEM_DIR}"
    echo "  [user]    ${PLASMA_USER_DIR}"
    echo ""
    read -rp "Proceed? [y/N] " ans
    [[ "${ans,,}" == "y" ]] || { info "Aborted."; exit 0; }
    echo ""
fi

# ── remove system QML plugin (requires sudo) ──────────────────────────────────
remove_system() {
    local removed=0
    for dir in "${QML_SYSTEM_DIR}" "${QML_SYSTEM_DIR_ALT}"; do
        if [[ -d "${dir}" ]]; then
            info "Removing system QML plugin: ${dir}"
            sudo rm -rf "${dir}" \
                && ok "Removed ${dir}" \
                || { error "Failed to remove ${dir}"; return 1; }
            removed=1
        fi
    done
    # Also remove the qmldir parent if now empty
    [[ "${removed}" == "0" ]] && warn "System QML plugin not found (already uninstalled?)"
}

# ── remove plasma user package ────────────────────────────────────────────────
remove_user_pkg() {
    if [[ -d "${PLASMA_USER_DIR}" ]]; then
        info "Removing user plasma package: ${PLASMA_USER_DIR}"
        # Try kpackagetool first (clean unregistration), fall back to rm
        if command -v kpackagetool6 &>/dev/null; then
            kpackagetool6 -t Plasma/Wallpaper -r "${PLUGIN_ID}" 2>/dev/null \
                && ok "Removed via kpackagetool6" \
                || { warn "kpackagetool6 removal failed, falling back to rm"; rm -rf "${PLASMA_USER_DIR}"; ok "Removed ${PLASMA_USER_DIR}"; }
        elif command -v kpackagetool &>/dev/null; then
            kpackagetool -t Plasma/Wallpaper -r "${PLUGIN_ID}" 2>/dev/null \
                && ok "Removed via kpackagetool" \
                || { warn "kpackagetool removal failed, falling back to rm"; rm -rf "${PLASMA_USER_DIR}"; ok "Removed ${PLASMA_USER_DIR}"; }
        else
            rm -rf "${PLASMA_USER_DIR}"
            ok "Removed ${PLASMA_USER_DIR}"
        fi
    else
        warn "User plasma package not found (already uninstalled?)"
    fi
}

# ── restart plasmashell ───────────────────────────────────────────────────────
restart_plasma() {
    info "Restarting plasmashell…"
    if systemctl --user is-active plasma-plasmashell.service &>/dev/null; then
        systemctl --user restart plasma-plasmashell.service \
            && ok "plasmashell restarted." \
            || warn "Could not restart plasmashell. Please log out and back in."
    else
        warn "plasma-plasmashell service not active. Please restart your KDE session."
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────
remove_system
remove_user_pkg

if [[ "${SKIP_RESTART}" == "0" ]]; then
    restart_plasma
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Uninstall complete."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
