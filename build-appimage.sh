#!/usr/bin/env bash
set -euo pipefail

APP_NAME="tealpp"
APP_VERSION="1.0"
APPDIR="AppDir"
BUNDLE_LOVE="${BUNDLE_LOVE:-0}"

# ---------- Ensure toolchain binaries exist (download if missing) ----------
mkdir -p static

if [ ! -x static/lua ]; then
    echo "Downloading static Lua 5.4 (~190 KB)..."
    wget -q -O static/lua \
        https://github.com/dyne/luabinaries/releases/latest/download/lua54
    chmod +x static/lua
fi

if [ ! -x static/tl ]; then
    echo "Downloading tl compiler..."
    TL_VERSION="0.24.8"
    TL_URL="https://github.com/teal-language/tl/releases/download/v${TL_VERSION}/tl-${TL_VERSION}-linux-x86_64.tar.gz"

    TMP_TL=$(mktemp -d)
    if ! wget -q -O "$TMP_TL/tl.tar.gz" "$TL_URL"; then
        echo "ERROR: could not download $TL_URL"
        rm -rf "$TMP_TL"; exit 1
    fi
    if ! tar -xzf "$TMP_TL/tl.tar.gz" -C "$TMP_TL" 2>/dev/null; then
        echo "ERROR: $TL_URL is not a valid gzip tarball"
        rm -rf "$TMP_TL"; exit 1
    fi

    TL_EXTRACTED=$(find "$TMP_TL" -type f -name tl -perm -u+x | head -1)
    if [ -z "$TL_EXTRACTED" ]; then
        echo "ERROR: tarball did not contain an executable named 'tl'"
        find "$TMP_TL" -type f
        rm -rf "$TMP_TL"; exit 1
    fi

    cp "$TL_EXTRACTED" static/tl
    chmod +x static/tl
    rm -rf "$TMP_TL"
    echo "  tl installed: $(static/tl --version 2>&1 | head -1 || echo 'unknown version')"
fi

# ---------- Validate ----------
[ -x static/lua ] || { echo "ERROR: static/lua missing"; exit 1; }
[ -x static/tl ]  || { echo "ERROR: static/tl missing"; exit 1; }
[ -f bin/tpp-cli.lua ] || { echo "ERROR: bin/tpp-cli.lua missing"; exit 1; }

if ldd static/lua 2>&1 | grep -q "libc.so" \
   && ! ldd static/lua 2>&1 | grep -q "not a dynamic"; then
    echo "WARN: static/lua is dynamically linked. It may not run on older systems."
    ldd static/lua
fi

# ---------- Build AppDir ----------
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/tealpp"
mkdir -p "$APPDIR/usr/share/metainfo"

# Lua interpreter
cp static/lua "$APPDIR/usr/bin/lua"
chmod +x "$APPDIR/usr/bin/lua"

# tl compiler
cp static/tl "$APPDIR/usr/bin/tl"
chmod +x "$APPDIR/usr/bin/tl"

# tpp launcher (needed so the desktop Exec= and AppStream see a real binary)
cat > "$APPDIR/usr/bin/tpp" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/lua" "$HERE/../share/tealpp/tpp-cli.lua" "$@"
EOF
chmod +x "$APPDIR/usr/bin/tpp"

# Teal++ runtime files
cp -r src     "$APPDIR/usr/share/tealpp/src"
cp -r gamekit "$APPDIR/usr/share/tealpp/gamekit"
cp bin/tpp-cli.lua "$APPDIR/usr/share/tealpp/"
cp gamekit.d.tl    "$APPDIR/usr/share/tealpp/"
[ -f PACKAGING.md ]       && cp PACKAGING.md       "$APPDIR/usr/share/tealpp/"
[ -f GETTING-STARTED.md ] && cp GETTING-STARTED.md "$APPDIR/usr/share/tealpp/"

# Optional: bundle LÖVE
if [ "$BUNDLE_LOVE" = "1" ]; then
    if [ -f love.AppImage ] || [ -f /usr/bin/love ] || command -v love >/dev/null; then
        mkdir -p "$APPDIR/usr/bin"
        if [ -f love.AppImage ]; then
            cp love.AppImage "$APPDIR/usr/bin/love"
        else
            cp "$(command -v love)" "$APPDIR/usr/bin/love"
        fi
        chmod +x "$APPDIR/usr/bin/love"
        echo "Bundled LÖVE runtime"
    else
        echo "WARN: BUNDLE_LOVE=1 but no love binary found"
    fi
fi

# ---------- AppRun ----------
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export PATH="$HERE/usr/bin:$PATH"
export TPP_PREFIX="$HERE/usr/share/tealpp"
exec "$HERE/usr/bin/lua" "$HERE/usr/share/tealpp/tpp-cli.lua" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# ---------- Desktop entry ----------
cat > "$APPDIR/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Name=Teal++
Exec=tpp
Icon=$APP_NAME
Type=Application
Categories=Development;
Terminal=true
EOF

# ---------- AppStream metadata ----------
# Filename must match <id> so appstreamcli doesn't warn about a mismatch.
APPDATA_ID="org.tealpp.tpp"
cat > "$APPDIR/usr/share/metainfo/${APPDATA_ID}.appdata.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="console-application">
  <id>${APPDATA_ID}</id>
  <name>Teal++</name>
  <summary>Teal++ compiler and GameKit toolchain</summary>
  <description>
    <p>
      Teal++ (tpp) is a superset of Lua with Teal types and a LÖVE game
      framework (GameKit). It bundles Lua 5.4 and the tl compiler so
      you can write games with a single-file command-line tool.
    </p>
    <p>Commands: build, check, run, love, bundle, package, test.</p>
  </description>
  <metadata_license>MIT</metadata_license>
  <project_license>MIT</project_license>
  <url type="homepage">https://github.com/Sheldevv/tealpp</url>
  <developer id="org.tealpp">
    <name>Sheldi</name>
  </developer>
  <content_rating type="oars-1.1"/>
  <provides>
    <binary>tpp</binary>
  </provides>
  <releases>
    <release version="${APP_VERSION}" date="$(date +%Y-%m-%d)"/>
  </releases>
</component>
EOF

# ---------- Icon ----------
if [ ! -f icon.png ]; then
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > icon.png
fi
cp icon.png "$APPDIR/$APP_NAME.png"

# ---------- Build ----------
if [ ! -f appimagetool-x86_64.AppImage ]; then
    wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

OUTPUT="$APP_NAME-$APP_VERSION-x86_64.AppImage"
rm -f "$OUTPUT"

# Try with AppStream validation; fall back to --no-appstream if it fails.
if ! ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APPDIR" "$OUTPUT"; then
    if [ -f "$OUTPUT" ]; then
        echo "WARN: appimagetool returned non-zero, but $OUTPUT was produced."
    else
        echo "appimagetool failed under AppStream validation; retrying with --no-appstream"
        ARCH=x86_64 ./appimagetool-x86_64.AppImage --no-appstream "$APPDIR" "$OUTPUT" || {
            rc=$?
            if [ -f "$OUTPUT" ]; then
                echo "WARN: appimagetool exited $rc but produced $OUTPUT"
            else
                echo "ERROR: appimagetool failed (exit $rc) and produced no output"
                exit $rc
            fi
        }
    fi
fi

echo ""
echo "Built: $OUTPUT"
echo "Size:  $(du -h "$OUTPUT" | cut -f1)"
