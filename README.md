# Teal++ + GameKit integration

This bundle includes the Teal++ class compiler, an application-source import-lowering mode, and the GameKit Lua runtime.

## The CLI now handles the whole workflow

You no longer need to manually create a temporary folder, copy GameKit, run the transpiler, run `tl gen`, and launch LÖVE as separate steps.

```sh
# Build a Teal++ application: lowers imports, type-checks, and generates Lua.
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

# Run included tests.
tpp test
```

The CLI automatically detects application files containing `import module.path as Alias`. Use `--program` to force application mode or `--class` to force the original class-definition mode. Existing legacy invocation remains supported:

```sh
tpp src/color.tpp
```

Use `-o` / `--output` to choose the generated `.tl` path, and `--no-check` to skip the `tl check` step during build/run/love. Teal (`tl`) is still required for checking and generating Lua; `lua` is required for `run`; LÖVE is required for `love`.

## Import syntax

```lua
import gamekit as GameKit
import gamekit.camera as Camera
```

The compiler lowers these lines to Lua/Teal `require` bindings and preserves the rest of the source for Teal to process.

## GameKit runtime staging

For application-mode `run` and `love` commands, the CLI stages `gamekit/` into the source project's directory if it is not already there. It also stages `gamekit.d.tl` when available. Existing project copies are not overwritten. This is intended to make the bundled GameKit example runnable with one command:

```sh
tpp love examples/tealpp/main.tpp
```

This stages the runtime/declaration files next to the example if they're missing; it does not overwrite existing ones. If you are building a separate project, run `tpp` from the bundle/repository that contains `src/tpp.lua`, `gamekit/`, and `gamekit.d.tl`, or install GameKit as a normal Lua module.

## Existing class mode

Class-definition compilation remains supported and remains the default for the legacy invocation `tpp file.tpp`. For the new `build`, `check`, `run`, and `love` commands, mode is detected from the presence of `import ... as ...` unless overridden with `--program` or `--class`.

## Current scope

This is an early application integration: Teal++ currently lowers its import aliases, while Teal checks and generates the rest of the application source. GameKit declarations are an initial permissive surface and should be tightened into precise API records in a later iteration.

## Tests

```sh
tpp test
```

Or run the tests individually with Lua, e.g. `lua tests/run_program.lua`. The automated suite covers import lowering, existing class compilation, GUI behavior, docking, camera helpers, and window management.
