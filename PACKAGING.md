# Packaging TGK Games

`tpp bundle` and `tpp package` produce distributable artifacts from a `.tpp` source.

## Quick reference

| Command | Output |
|---|---|
| `tpp bundle main.tpp` | `build/main/`, `build/main.love`, `build/main.sh` |
| `tpp package main.tpp --target linux` | `dist/main-linux.tar.gz` |
| `tpp package main.tpp --target windows --love-bin ~/love-win` | `dist/main-windows.zip` |
| `tpp package main.tpp --target macos --love-bin ~/love.app` | `dist/main-macos.tar.gz` |

`.love` files are cross-platform — any user with LÖVE installed can run one regardless of their OS.

## Prerequisites

- **LÖVE 11+** installed on the dev machine (for `tpp love` during testing)
- **Teal** (`luarocks install tl`)
- **`zip` and `tar`** — usually pre-installed on macOS; `apt install zip tar` on Debian/Ubuntu
- **LÖVE runtime for the target OS**, downloaded from https://love2d.org:
  - **Linux:** the `love` binary from a distro package or AppImage
  - **Windows:** the `.zip` from love2d.org (extract it — the folder contains `love.exe` and DLLs)
  - **macOS:** the `.dmg` from love2d.org (extract `love.app`)

The CLI does not download runtimes. You provide them with `--love-bin`.

## Linux

```sh
# Simplest — .love only (user must have LÖVE installed)
tpp package examples/showcase/main.tpp --target linux
# -> dist/main-linux.tar.gz

# Bundled runtime — ships the love binary with your game
tpp package examples/showcase/main.tpp --target linux --love-bin /usr/bin/love
# -> dist/main-linux.tar.gz  (~2 MB)

# Test it
mkdir /tmp/test && tar -xzf dist/main-linux.tar.gz -C /tmp/test
cd /tmp/test/main-linux && ./run.sh
```

The archive contains:

```
main-linux/
├── main.love          the game (zip)
├── love               (if --love-bin provided)
├── run.sh             launcher (executable)
└── README.txt         (if no --love-bin)
```

## Windows

Windows packaging **requires** `--love-bin` pointing at the extracted LÖVE Windows folder (the one containing `love.exe`):

```sh
# 1. Download love-11.4-win64.zip from https://love2d.org/wiki/11.4
# 2. Extract it somewhere (say ~/love-11.4-win64)
# 3. Package
tpp package examples/showcase/main.tpp --target windows --love-bin ~/love-11.4-win64
# -> dist/main-windows.zip
```

The archive contains:

```
main-windows/
├── main.exe              fused love.exe + game (double-clickable)
├── main.love             original .love (drag onto love.exe)
├── love.exe
├── SDL2.dll, OpenAL32.dll, ...
└── README.txt
```

**How the fusion works:** `cat love.exe main.love > main.exe`. LÖVE's binary knows how to read a `.zip` appended to itself. This is LÖVE's standard distribution mechanism. No external tooling beyond `cat`.

Copy the folder to a Windows machine and double-click `main.exe`.

## macOS

```sh
# 1. Download love-11.4-macos.zip, extract love.app
# 2. Package
tpp package examples/showcase/main.tpp --target macos --love-bin ~/love.app
# -> dist/main-macos.tar.gz
```

The archive contains:

```
main-macos/
├── main.app/
│   ├── Contents/
│   │   ├── MacOS/love
│   │   ├── Resources/
│   │   │   └── main.love    (your game, embedded)
│   │   └── Info.plist
├── main.love
└── README.txt               (codesign/notarize guidance)
```

The `.app` is **unsigned**. For distribution you must:

```sh
# Sign (requires an Apple Developer ID certificate in your keychain)
codesign --deep --force --sign "Developer ID Application: Your Name (TEAMID)" main.app

# Notarize (requires an Apple ID app-specific password)
ditto -c -k --keepParent main.app main.zip
xcrun notarytool submit main.zip --wait --apple-id you@example.com --password <app-specific> --team-id TEAMID

# Staple
xcrun stapler staple main.app
```

See Apple's documentation: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution

For **local testing on your own Mac**, unsigned `.app` bundles usually launch. Users who download them see a Gatekeeper warning until notarized.

## Testing a bundle without packaging

`tpp bundle` produces the intermediate files and a dev launcher:

```sh
tpp bundle examples/showcase/main.tpp
./build/main.sh          # runs via system love
```

Use this to sanity-check before spending time packaging.

## Cleaning

```sh
rm -rf build/ dist/
```

Build artifacts are regenerated on every `tpp bundle` / `tpp package` call.

## Troubleshooting

| Problem | Fix |
|---|---|
| `'zip' not installed` | `apt install zip` / `brew install zip` |
| Windows `main.exe` won't run | Ensure all DLLs from the LÖVE folder are present — the fused `.exe` still needs the sibling DLLs |
| macOS `.app` shows "damaged" | Run `xattr -cr main.app` after copying from a downloaded zip, or complete codesigning + notarization |
| `.love` file won't open | LÖVE not installed, or file association missing (on macOS: `open -a love main.love`) |
| `cat: love.exe: No such file` during windows package | `--love-bin` must point at the extracted folder, not the zip |
