# Teal++ + GameKit integration

This bundle includes the Teal++ class compiler, an application-source
import-lowering mode, and the GameKit Lua runtime.

## The CLI handles the whole workflow

You no longer need to manually create a temporary folder, copy GameKit,
run the transpiler, run `tl gen`, and launch LÖVE as separate steps.

```sh
# Build a Teal++ application: lowers imports, type-checks, generates Lua.
tpp build examples/tealpp/main.tpp

# Run a plain Lua program after building it.
tpp run examples/tealpp/tool.tpp

# Build and launch a LÖVE project. `main.tpp` should generate `main.lua`.
tpp love examples/tealpp/main.tpp

# Type-check only.
tpp check examples/tealpp/main.tpp

# Stage a distributable bundle (main.love + gamekit/ + dev launcher).
tpp bundle examples/showcase/main.tpp

# Produce a Linux distributable.
tpp package examples/showcase/main.tpp --target linux

# Produce a Windows distributable (needs the Windows LÖVE zip extracted).
tpp package examples/showcase/main.tpp --target windows --love-bin ~/love-11.4-win64

# Produce a macOS .app bundle (needs love.app).
tpp package examples/showcase/main.tpp --target macos --love-bin ~/love.app

# Produce a browser-playable build via love.js.
tpp package examples/showcase/main.tpp --target web

# Run included tests (including linux + web packaging smoke tests).
tpp test

# Remove the source install (see uninstall.sh for details).
tpp uninstall
```

The CLI automatically detects application files containing
`import module.path as Alias`. Use `--program` to force application mode
or `--class` to force the original class-definition mode. Existing legacy
invocation remains supported:

```sh
tpp src/color.tpp
```

Use `-o` / `--output` to choose the generated `.tl` path, and `--no-check`
to skip the `tl check` step during build/run/love. Teal (`tl`) is still
required for checking and generating Lua; `lua` is required for `run`;
LÖVE is required for `love`.

## Import syntax

```lua
import gamekit as GameKit
import gamekit.camera as Camera
```

The compiler lowers these lines to Lua/Teal `require` bindings and
preserves the rest of the source for Teal to process.

## GameKit runtime staging

For application-mode `run` and `love` commands, the CLI stages `gamekit/`
into the source project's directory if it is not already there. It also
stages `gamekit.d.tl` when available. Existing project copies are not
overwritten. This is intended to make the bundled GameKit example runnable
with one command:

```sh
tpp love examples/tealpp/main.tpp
```

This stages the runtime/declaration files next to the example if they're
missing; it does not overwrite existing ones. If you are building a
separate project, run `tpp` from the bundle/repository that contains
`src/tpp.lua`, `gamekit/`, and `gamekit.d.tl`, or install GameKit as a
normal Lua module.

## Web builds (love.js)

`tpp package <file>.tpp --target web` produces a browser-playable build
using the prebuilt love.js player bundled as `love.js.zip` at the repo
root.

### Requirements

- `unzip` on the dev machine (usually preinstalled)
- `love.js.zip` at the repo root, or pass `--love-bin <path-to-zip>`

### Output

`dist/<name>-web.tar.gz`, containing:

```
<name>-web/
├── index.html
├── love.wasm
├── love.js
├── game.data        <- your compiled .love file
└── README.txt
```

### Running locally

Web builds **cannot** be opened from `file://`. Serve them over HTTP:

```sh
mkdir -p /tmp/web
tar -xzf dist/showcase-web.tar.gz -C /tmp/web
cd /tmp/web/showcase-web
python3 -m http.server 8080
# open http://localhost:8080
```

### Deploying

Upload every file in `<name>-web/` to any static host — itch.io,
GitHub Pages, Netlify, Cloudflare Pages. The game itself is `game.data`;
replace it to update the game without reuploading the player.

### Compatibility mode

The bundled `love.js.zip` uses the compatibility build (no pthreads).
Audio may be slightly delayed and the browser may require a click on
the canvas before sound plays. In exchange, no COOP/COEP headers are
needed, so itch.io and GitHub Pages work out of the box.

If you replace `love.js.zip` with a non-compatibility build, add these
headers to your server:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

### Known limitations

- WebGL only; no Vulkan or Metal shaders
- Larger games take longer to load (`.wasm` + `.data` download)
- `love.filesystem` writes are not persisted (browser sandbox)
- Save data must use `localStorage` (future GameKit feature)

## Existing class mode

Class-definition compilation remains supported and remains the default
for the legacy invocation `tpp file.tpp`. For the new `build`, `check`,
`run`, `love`, `bundle`, and `package` commands, mode is detected from
the presence of `import ... as ...` unless overridden with `--program`
or `--class`.

## Current scope

Teal++ currently lowers its import aliases, while Teal checks and
generates the rest of the application source. GameKit declarations are
an initial permissive surface and should be tightened into precise API
records in a later iteration.

## Tests

```sh
tpp test
```

Or run the tests individually with Lua, e.g. `lua tests/run_program.lua`.
The automated suite covers import lowering, existing class compilation,
GUI behavior, docking, camera helpers, window management, and packaging
smoke tests for Linux and web targets.
