# Neon Survivor — Teal++

A top-down arcade survival game written in `.tpp` and run with LÖVE.

Controls:
- WASD / arrow keys: move
- Auto-fire targets the nearest enemy
- Enter: restart after game over

Copy this folder to `examples/neon_survivor/` in your Teal++ project, then from the project root run:

```bash
./bin/tpp love examples/neon_survivor/main.tpp
```

If your local `tpp love` CLI still has the output-path bug, enter the example directory and run:

```bash
tl check main.tl
tl gen main.tl
love .
```

Edit `main.tpp`; `main.tl` and `main.lua` are generated files.
