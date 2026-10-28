#!/usr/bin/env bash
# Teal++ (tpp) automatic installer.
#
# Installs the tpp CLI, compiler, and GameKit runtime into a prefix directory
# (default: ~/.local/tpp) and drops a `tpp` wrapper into $TPP_BIN_DIR
# (default: ~/.local/bin).
#
# Usage:
#   ./install.sh                                                # defaults
#   TPP_INSTALL_DIR=$HOME/.local ./install.sh
#   TPP_GIT_REPO=https://github.com/me/tealpp.git ./install.sh
#   TPP_INSTALL_DIR=/usr/local sudo -E ./install.sh             # system-wide
#
# Edit the CONFIG block below to customize the defaults.

set -euo pipefail

# ============================================================
# CONFIG
# ============================================================

# Where to clone the source from. Any URL git accepts.
TPP_GIT_REPO="${TPP_GIT_REPO:-https://github.com/YOUR_USERNAME/tealpp.git}"

# Branch or tag to install.
TPP_GIT_BRANCH="${TPP_GIT_BRANCH:-main}"

# Where to install (default: user-local).
TPP_INSTALL_DIR="${TPP_INSTALL_DIR:-$HOME/.local}"

# Where the actual tpp files go.
TPP_PREFIX="${TPP_PREFIX:-$TPP_INSTALL_DIR/tpp}"

# Where the `tpp` command lives.
TPP_BIN_DIR="${TPP_BIN_DIR:-$TPP_INSTALL_DIR/bin}"

# Set to 1 to skip dependency checks.
TPP_SKIP_DEPS="${TPP_SKIP_DEPS:-0}"

# Set to 1 to suppress the PATH warning.
TPP_NO_PATH_HINT="${TPP_NO_PATH_HINT:-0}"

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
# CLEANUP
# ============================================================

TPP_TMP=""
cleanup() {
    if [ -n "$TPP_TMP" ] && [ -d "$TPP_TMP" ]; then
        rm -rf "$TPP_TMP"
    fi
}
trap cleanup EXIT INT TERM

# ============================================================
# PREFLIGHT
# ============================================================

preflight() {
    if [ "$(id -u)" = "0" ]; then
        warn "Running as root. Installing to: $TPP_INSTALL_DIR"
        warn "For system-wide install use: TPP_INSTALL_DIR=/usr/local"
    fi

    if [ -e "$TPP_INSTALL_DIR" ] && [ ! -w "$TPP_INSTALL_DIR" ]; then
        die "$TPP_INSTALL_DIR exists but is not writable"
    fi

    mkdir -p "$TPP_INSTALL_DIR"
}

# ============================================================
# DEPENDENCIES
# ============================================================

check_deps() {
    if [ "$TPP_SKIP_DEPS" = "1" ]; then
        log "Skipping dependency check"
        return 0
    fi

    log "Checking dependencies..."
    local missing=""
    for cmd in lua git; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        err "Missing required tools:$missing"
        echo ""
        case "$(uname -s)" in
            Linux*)
                echo "  Debian/Ubuntu:  sudo apt install lua5.4 git zip"
                echo "  Fedora/RHEL:    sudo dnf install lua git zip"
                echo "  Arch:           sudo pacman -S lua git zip"
                ;;
            Darwin*)
                echo "  brew install lua git zip"
                ;;
        esac
        exit 1
    fi

    local has_tl=0 has_zip=0 has_love=0
    command -v tl   >/dev/null 2>&1 && has_tl=1
    command -v zip  >/dev/null 2>&1 && has_zip=1
    command -v love >/dev/null 2>&1 && has_love=1

    if [ "$has_tl" = "0" ] || [ "$has_zip" = "0" ] || [ "$has_love" = "0" ]; then
        warn "Optional dependencies missing:"
        [ "$has_tl" = "0" ]   && echo "    tl    -- install with: luarocks install tl"
        [ "$has_zip" = "0" ]  && echo "    zip   -- Debian: apt install zip  |  macOS: brew install zip"
        [ "$has_love" = "0" ] && echo "    love  -- https://love2d.org"
        echo ""
        echo "    tl is needed for 'tl check' and 'tl gen' (tpp build/check/run/love)."
        echo "    zip is needed for 'tpp bundle' and 'tpp package'."
        echo "    love is needed for 'tpp love' and bundled-LÖVE packages."
        echo ""
    fi

    ok "Dependencies OK"
}

# ============================================================
# FETCH
# ============================================================

fetch() {
    TPP_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t tpp-install)

    log "Cloning $TPP_GIT_REPO (branch: $TPP_GIT_BRANCH)..."
    if ! git clone --depth 1 --branch "$TPP_GIT_BRANCH" "$TPP_GIT_REPO" "$TPP_TMP" >/dev/null 2>&1; then
        die "git clone failed. Check TPP_GIT_REPO and TPP_GIT_BRANCH."
    fi

    [ -f "$TPP_TMP/src/tpp.lua" ]      || die "repo missing src/tpp.lua"
    [ -f "$TPP_TMP/gamekit/init.lua" ] || die "repo missing gamekit/init.lua"
    [ -f "$TPP_TMP/bin/tpp-cli.lua" ]  || die "repo missing bin/tpp-cli.lua"

    ok "Fetched"
}

# ============================================================
# INSTALL
# ============================================================

install_files() {
    local src="$TPP_TMP"
    local updating=""
    [ -d "$TPP_PREFIX" ] && updating=" ${C_DIM}(updating existing)${C_RESET}"

    log "Installing to $TPP_PREFIX$updating"

    mkdir -p "$TPP_PREFIX" "$TPP_PREFIX/bin" "$TPP_BIN_DIR"

    # Remove previous tpp-owned files (doesn't touch anything else)
    rm -rf "$TPP_PREFIX/bin" "$TPP_PREFIX/src" "$TPP_PREFIX/gamekit"
    rm -f  "$TPP_PREFIX/gamekit.d.tl"
    rm -f  "$TPP_PREFIX/PACKAGING.md" "$TPP_PREFIX/GETTING-STARTED.md"

    mkdir -p "$TPP_PREFIX/bin"

    cp "$src/bin/tpp-cli.lua" "$TPP_PREFIX/bin/tpp-cli.lua"
    cp -R "$src/src"          "$TPP_PREFIX/src"
    cp -R "$src/gamekit"      "$TPP_PREFIX/gamekit"

    [ -f "$src/gamekit.d.tl" ]       && cp "$src/gamekit.d.tl"       "$TPP_PREFIX/"
    [ -f "$src/PACKAGING.md" ]       && cp "$src/PACKAGING.md"       "$TPP_PREFIX/"
    [ -f "$src/GETTING-STARTED.md" ] && cp "$src/GETTING-STARTED.md" "$TPP_PREFIX/"

    chmod +x "$TPP_PREFIX/bin/tpp-cli.lua"

    # Generate the wrapper with the install-time path baked in
    cat > "$TPP_BIN_DIR/tpp" <<EOF
#!/bin/sh
TPP_PREFIX="\${TPP_PREFIX:-$TPP_PREFIX}"
exec lua "\$TPP_PREFIX/bin/tpp-cli.lua" "\$@"
EOF
    chmod +x "$TPP_BIN_DIR/tpp"

    ok "Files installed"
}

# ============================================================
# VERIFY
# ============================================================

verify() {
    log "Verifying..."
    if ! "$TPP_BIN_DIR/tpp" --help >/dev/null 2>&1; then
        die "installed tpp failed to run --help"
    fi
    ok "tpp --help works"
}

# ============================================================
# PATH HINT
# ============================================================

path_hint() {
    [ "$TPP_NO_PATH_HINT" = "1" ] && return 0

    case ":$PATH:" in
        *":$TPP_BIN_DIR:"*) return 0 ;;
    esac

    echo ""
    warn "$TPP_BIN_DIR is not in PATH."
    echo ""
    case "${SHELL:-}" in
        *fish*)
            echo "  Run once:"
            echo "    fish_add_path $TPP_BIN_DIR"
            ;;
        *)
            echo "  Add to ~/.bashrc or ~/.zshrc:"
            echo "    export PATH=\"$TPP_BIN_DIR:\$PATH\""
            echo ""
            echo "  Then restart your shell."
            ;;
    esac
}

# ============================================================
# MAIN
# ============================================================

main() {
    echo ""
    echo "${C_BOLD}Teal++ (tpp) installer${C_RESET}"
    echo "${C_DIM}=================================================${C_RESET}"
    echo "  repo:     $TPP_GIT_REPO"
    echo "  branch:   $TPP_GIT_BRANCH"
    echo "  prefix:   $TPP_PREFIX"
    echo "  wrapper:  $TPP_BIN_DIR/tpp"
    echo "${C_DIM}=================================================${C_RESET}"
    echo ""

    preflight
    check_deps
    fetch
    install_files
    verify
    path_hint

    echo ""
    ok "${C_BOLD}Done.${C_RESET}"
    echo ""
    echo "  Try it:"
    echo "    tpp --help"
    echo "    cd your-game-dir && tpp love main.tpp"
    echo ""
    echo "  Docs:"
    echo "    $TPP_PREFIX/GETTING-STARTED.md"
    echo "    $TPP_PREFIX/PACKAGING.md"
    echo ""
}

main "$@"
