#!/usr/bin/env bash
# Teal++ (tpp) uninstaller.
#
# Removes files installed by install.sh. Never touches anything else:
#   - No system packages removed.
#   - No user game projects touched.
#   - No changes outside TPP_PREFIX and TPP_BIN_DIR.
#
# Usage:
#   ./uninstall.sh                        # prompts before deleting
#   ./uninstall.sh --yes                  # skip prompt (for scripts)
#   TPP_INSTALL_DIR=$HOME/.local ./uninstall.sh
#   TPP_INSTALL_DIR=/usr/local sudo -E ./uninstall.sh
#
# The AppImage does NOT need an uninstaller — just delete the file.

set -euo pipefail

# ============================================================
# CONFIG  (must match install.sh)
# ============================================================

TPP_INSTALL_DIR="${TPP_INSTALL_DIR:-$HOME/.local}"
TPP_PREFIX="${TPP_PREFIX:-$TPP_INSTALL_DIR/tpp}"
TPP_BIN_DIR="${TPP_BIN_DIR:-$TPP_INSTALL_DIR/bin}"
TPP_ASSUME_YES="${TPP_ASSUME_YES:-0}"

# ============================================================
# COLORS
# ============================================================

if [ -t 1 ]; then
    C_RED=$(printf '\033[0;31m')
    C_GREEN=$(printf '\033[0;32m')
    C_YELLOW=$(printf '\033[0;33m')
    C_BLUE=$(printf '\033[0;34m')
    C_BOLD=$(printf '\033[1m')
    C_DIM=$(printf '\033[2m')
    C_RESET=$(printf '\033[0m')
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""; C_DIM=""; C_RESET=""
fi

log()  { printf '%s[*]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s[x]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ============================================================
# SCAN — what would we remove?
# ============================================================

declare -a TO_REMOVE=()

scan() {
    if [ -d "$TPP_PREFIX" ]; then
        TO_REMOVE+=("$TPP_PREFIX")
    fi

    # Only remove the wrapper if it's ours (checks the marker line we wrote).
    if [ -f "$TPP_BIN_DIR/tpp" ]; then
        if grep -q "TPP_PREFIX=" "$TPP_BIN_DIR/tpp" 2>/dev/null; then
            TO_REMOVE+=("$TPP_BIN_DIR/tpp")
        else
            warn "Skipping $TPP_BIN_DIR/tpp — it exists but doesn't look like ours."
            warn "  (If you're sure, remove it manually.)"
        fi
    fi
}

# ============================================================
# CONFIRM
# ============================================================

confirm() {
    if [ "${#TO_REMOVE[@]}" -eq 0 ]; then
        log "Nothing to uninstall from:"
        echo "    prefix:   $TPP_PREFIX"
        echo "    wrapper:  $TPP_BIN_DIR/tpp"
        echo ""
        echo "  If you installed via the AppImage, just delete the .AppImage file."
        exit 0
    fi

    echo ""
    echo "${C_BOLD}Teal++ uninstaller${C_RESET}"
    echo "${C_DIM}=================================================${C_RESET}"
    echo "  Will remove:"
    for path in "${TO_REMOVE[@]}"; do
        echo "    $path"
    done
    echo "${C_DIM}=================================================${C_RESET}"
    echo ""

    if [ "$TPP_ASSUME_YES" = "1" ]; then
        return 0
    fi

    if [ -t 0 ]; then
        printf "Remove these files? [y/N] "
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS]) return 0 ;;
            *) echo "Aborted."; exit 0 ;;
        esac
    else
        warn "Not running in a terminal; use --yes to confirm."
        exit 1
    fi
}

# ============================================================
# REMOVE
# ============================================================

remove_files() {
    for path in "${TO_REMOVE[@]}"; do
        if [ -e "$path" ]; then
            log "Removing $path"
            rm -rf "$path"
        fi
    done
}

# ============================================================
# PATH HINT
# ============================================================

cleanup_hint() {
    echo ""
    if command -v tpp >/dev/null 2>&1; then
        local found
        found=$(command -v tpp)
        warn "A 'tpp' binary is still on your PATH: $found"
        warn "  This is likely from a different install (AppImage, another shell, etc.)."
    fi

    case ":$PATH:" in
        *":$TPP_BIN_DIR:"*)
            echo ""
            echo "  ${C_DIM}Note:${C_RESET} $TPP_BIN_DIR is still on your PATH."
            echo "        Remove it from ~/.bashrc / ~/.zshrc / fish config if you like."
            ;;
    esac
}

# ============================================================
# MAIN
# ============================================================

main() {
    # Parse args
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) TPP_ASSUME_YES=1; shift ;;
            -h|--help)
                cat <<EOF
Teal++ uninstaller.

Removes files installed by install.sh from:
    $TPP_PREFIX
    $TPP_BIN_DIR/tpp

Options:
    -y, --yes     Skip the confirmation prompt
    -h, --help    Show this help

Environment (must match install.sh):
    TPP_INSTALL_DIR    default: \$HOME/.local
    TPP_PREFIX         default: \$TPP_INSTALL_DIR/tpp
    TPP_BIN_DIR        default: \$TPP_INSTALL_DIR/bin

The AppImage does not need this script — just delete the file.
EOF
                exit 0 ;;
            *) die "unknown option: $1 (try --help)" ;;
        esac
    done

    scan
    confirm
    remove_files

    echo ""
    ok "Uninstalled."
    cleanup_hint
    echo ""
}

main "$@"
