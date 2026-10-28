# Getting Started with Teal++ GameKit

Write a game in a single `.tpp` file. One command runs it.

## Prerequisites

- **LÖVE 11+** — https://love2d.org
- **Teal** — `luarocks install tl`
- **Teal++** — this repository, cloned somewhere and on `PATH` via `./bin/tpp`

## Hello, window

Save this as `hello.tpp`:

```lua
import gamekit as GameKit

GameKit.app({ title = "hello", width = 640, height = 480 })

function draw()
    GameKit.graphics.clear("#0b0d18")
    local w, h = GameKit.graphics.getDimensions()
    GameKit.graphics.circle("fill", w / 2, h / 2, 48, "#15f5ff")
end
```

Run it:

```sh
./bin/tpp love hello.tpp
```

That's the whole ceremony. `GameKit.app` opens the window, wires LÖVE's lifecycle, and dispatches your `draw` / `update` / `keypressed` functions automatically.

## Animate with `update(dt)`

```lua
function update(dt: number)
    t = t + dt
end
```

`dt` is seconds since the last frame. Use it to move things at frame-rate-independent speeds:

```lua
state.x = state.x + 200 * dt  -- 200 pixels per second, right
```

## Handle input

```lua
GameKit.Input.bind("fire", "space", "mouse:1")

function update(dt: number)
    if GameKit.Input.pressed("fire") then
        -- fires once per press
    end
    if GameKit.Input.down("fire") then
        -- true while held
    end
end
```

Sources are any keyboard key name (`"space"`, `"w"`, `"left"`), or `"mouse:N"` where N is 1=left, 2=right, 3=middle. Bind multiple sources to one action and any of them works.

## Draw shapes, text, images

```lua
GameKit.graphics.circle("fill", x, y, r, "#ff6b9d")
GameKit.graphics.rectangle("line", x, y, w, h, "#ffffff")
GameKit.graphics.line(x1, y1, x2, y2, "#888")
GameKit.graphics.print("score: 42", 20, 20, "#ffffff")
GameKit.graphics.image(img, x, y, 0, 1, 1)  -- rotation, sx, sy
```

Colors accept `"#rrggbb"`, `"#rrggbbaa"`, or `{r, g, b, a}` in 0..1.

## Load images, fonts, sounds

```lua
local player = GameKit.assets.image("assets/player.png")
local font   = GameKit.assets.font("assets/ui.ttf", 18)
local beep   = GameKit.assets.sound("assets/beep.wav")
local music  = GameKit.assets.music("assets/theme.ogg")
```

Missing files **log a warning and return `nil`** — your game keeps running. Check for `nil` before using:

```lua
if player then
    GameKit.graphics.image(player, x, y)
end
```

## Play audio

```lua
GameKit.audio.play(beep, 0.6)          -- fire and forget
GameKit.audio.playMusic(music, 0.4)    -- loops, one at a time
GameKit.audio.setMasterVolume(0.8)     -- affects everything
GameKit.audio.fadeOut(music, 2.0)      -- fades over 2s
```

## Add a GUI

```lua
local ui = GameKit.GUI.new({ x = 20, y = 20, w = 220 })
ui:label("score: 0")
ui:button("Reset", function() score = 0 end)
ui:checkbox("Mute", false, function(m) GameKit.audio.setMasterVolume(m and 0 or 1) end)

GameKit.app({ ..., gui = ui })
```

That's it. The GUI attaches automatically — mouse clicks, keyboard focus, text input, all wired. No `LoveGUI.attach`, no `ui:update(dt)`, no `ui:draw(renderer)`.

## Timers

```lua
GameKit.Timer.every(1.5, function()
    spawn_enemy()
end)

GameKit.Timer.after(3.0, function()
    start_wave()
end)
```

## Screen shake / camera

```lua
local cam = GameKit.Camera.new({ width = 800, height = 600 })

function draw()
    cam:attachLove()
    -- draw world here
    cam:detachLove()
    -- draw HUD here (not affected by camera)
end
```

## Error handling

Every callback is `pcall`-wrapped. If `update` throws, the game logs a traceback and keeps running instead of crashing:

```lua
GameKit.app({
    on_error = function(traceback) print("ouch:", traceback) end,
})
```

## Project layout

```
my_game/
├── main.tpp                 -- your game
├── conf.lua                 -- optional LÖVE config
├── assets/
│   ├── player.png
│   ├── ui.ttf
│   └── theme.ogg
├── gamekit/                 -- staged automatically by `tpp love`
└── gamekit.d.tl
```

## Building for distribution

```sh
./bin/tpp build my_game/main.tpp        # main.tl + main.lua
./bin/tpp check my_game/main.tpp        # type-check only
./bin/tpp love  my_game/main.tpp        # build + run
```

For distribution, zip `main.lua`, `conf.lua`, `assets/`, and `gamekit/` and drop `main.lua`'s directory into `love.exe` / `love` alongside the runtime. Detailed packaging guidance is in `PACKAGING.md` (Milestone 4).

## Common problems

| Symptom | Fix |
|---|---|
| `GameKit.app: error in load callback` | A global callback was named after a Lua builtin. Rename it. |
| `functions need an explicit 'local' or 'global' annotation` | Your `.tpp` has `function foo()` at top level without `local`. Add `global function foo()` or move inside `local`. |
| `cannot index key 'X' in variable 'GameKit' of type boolean` | `gamekit.d.tl` failed to parse. Look earlier in the check output for the real syntax error. |
| `attempt to call nil value (global 'update')` | You defined `update` but forgot to `GameKit.app()` — dispatch only runs through the app wrapper. |
| `integer` vs `number` errors | `local n = 0` is integer, `local n = 0.0` is number. Use `0.0` when you'll add `dt`. |
| Staged `gamekit/` copy is stale after edits | `rm -rf <game_dir>/gamekit <game_dir>/gamekit.d.tl` before `tpp love`. |

## Where next?

- Full example: `examples/showcase/main.tpp` — movement, timers, GUI, assets, audio
- GUI demo: `examples/gui/main.tpp`
- Minimal: `examples/hello/main.tpp`
- Full API: `gamekit.d.tl`
```
