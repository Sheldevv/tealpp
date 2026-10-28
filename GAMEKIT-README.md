# Teal++ GameKit

A lightweight, shared game-development toolkit for Teal++ projects targeting LÖVE and LÖVR.

## Features

- Scene lifecycle and switching
- Action-based input bindings
- One-shot and repeating timers
- Separate LÖVE and LÖVR callback adapters
- Themed GUI widgets: labels, buttons, checkboxes, text inputs, sliders and progress bars
- Vertical/horizontal layouts, nested containers and scrollable panels
- Advanced GUI: dropdowns, radio groups, tooltips, keyboard focus/navigation, and runtime theme updates
- Backend-agnostic dockable panel manager with dragging, resizing, collapse/restore, and edge docking
- 2D camera math: world/screen conversion, rotation, cursor-centered zoom, viewport bounds, and optional LÖVE transform helpers
- Responsive UI sizing and bounds updates after window resizing
- LÖVE window controls for size, fullscreen, borderless mode, title, minimum size, resizability and VSync
- No third-party Lua dependencies

## Requirements

- Lua compatible with the target framework
- LÖVE for 2D games, or LÖVR for 3D/VR games

The shared GameKit modules use ordinary Lua so they can run without the Teal++ compiler.

## Run the LÖVE demo

From the Teal++ project root:

```sh
cp examples/love/main.lua main.lua
cp examples/love/conf.lua conf.lua
love .
```

## Run the LÖVR demo

From the project root:

```sh
cp examples/lovr/main.lua main.lua
lovr .
```

These commands replace the root `main.lua` with the selected demo. Commit or back up any existing file before doing this.

## GUI layouts and containers

```lua
local GUI = require("gamekit.gui")
local ui = GUI.new({
    x = 24, y = 24, w = 420,
    padding = 12, spacing = 8,
    direction = "vertical", -- or "horizontal"
    responsive = true,
    right_margin = 24,
    max_width = 600,
})

ui:label("Settings")
local panel = ui:container({height = 180, scrollable = true})
panel:button("Nested button", function() print("clicked") end)
panel:checkbox("Enable feature", true)

-- Optional: manually position/size a panel.
ui:setBounds(24, 24, 480)
-- Called by the window adapter when the OS window is resized.
ui:resize(1280, 720)
```

Vertical layouts stack widgets. Horizontal layouts distribute the available width between widgets without an explicit width. Containers have their own widgets and can be nested; scrollable containers respond to the mouse wheel.


## Advanced GUI widgets

```lua
local ui = require("gamekit.gui").new({width = 360})
ui:radio("Windowed", true, function() print("Windowed") end, {group = "display"})
ui:radio("Fullscreen", false, function() print("Fullscreen") end, {group = "display"})
local quality = ui:dropdown({
    items = {"Fast", "Balanced", "Pretty"}, selected = 2,
    callback = function(index, label) print(index, label) end,
})
ui:setTooltip(quality, "Choose a rendering preset.")
ui:setTheme({accent = {0.95, 0.45, 0.25, 1}})
-- Or start with a reusable built-in palette:
local lightUI = require("gamekit.gui").new({theme = require("gamekit.gui").themes.light})
```

Use **Tab** to move keyboard focus, **Enter/Space** to activate focused controls, arrow keys to adjust sliders or move through a radio group, and arrow keys/Enter/Escape to operate a focused dropdown. Tooltips appear after the configured delay (`tooltip_delay` in `GUI.new`, or a per-widget delay in `setTooltip`).

## Dockable panels

```lua
local Dock = require("gamekit.dock")
local GUI = require("gamekit.gui")
local LoveGUI = require("gamekit.gui_love")

local dock = Dock.new({x = 16, y = 16, width = 1200, height = 680})
local renderer = LoveGUI.new()
local inspector = GUI.new({width = 280})
inspector:label("Inspector")
inspector:button("Build", function() print("Build!") end)
dock:add("inspector", {
    title = "Inspector", x = 24, y = 24, width = 300, height = 400,
    content = inspector,
})
dock:add("scene", {title = "Scene", dock = "left", width = 240, height = 680})

-- The manager implements the same mouse/key methods as the GUI, so it can
-- be attached directly to LÖVE's callbacks.
local detach = LoveGUI.attach(dock)
function love.draw() dock:draw(renderer) end
-- Call detach() when the editor shuts down.
```

Panels can be moved by their title bars, resized from the bottom-right grip, collapsed with the title-bar control, and placed in `left`, `right`, `top`, `bottom`, or `float` mode with `dock:setDock(panel, zone)`. `content` may be a GameKit GUI instance or any object implementing `draw(renderer)` and relevant input methods.

## Camera and viewport utilities

```lua
local Camera = require("gamekit.camera")
local camera = Camera.new({x = 0, y = 0, zoom = 1, width = 1280, height = 720})
camera:move(20, 0)
camera:zoomBy(1.2, mouseX, mouseY) -- zoom toward the cursor
local screenX, screenY = camera:worldToScreen(worldX, worldY)
local worldX, worldY = camera:screenToWorld(screenX, screenY)
local left, top, width, height = camera:getVisibleWorldBounds()

-- In LÖVE, bracket world drawing with:
camera:attachLove()
-- draw world objects here
camera:detachLove()
```

The coordinate math is framework-independent and useful in both LÖVE and LÖVR projects. `attachLove` / `detachLove` are optional LÖVE-only helpers; use the conversion methods with your own renderer in LÖVR.

## Advanced demo

From the project root, copy `examples/love/advanced_demo.lua` to `main.lua`, copy `examples/love/conf.lua` to `conf.lua`, then run `love .`. The demo combines keyboard-accessible GUI controls, a movable/resizable panel layout, and a zoomable camera viewport.

## LÖVE window management

```lua
local Window = require("gamekit.window_love")

Window.setTitle("My Game")
Window.setSize(1280, 720)
Window.setMinSize(640, 480) -- also enables resizing
Window.setResizable(true)
Window.setFullscreen(true) -- optionally pass "desktop" or "exclusive"
Window.setBorderless(false)
Window.setVSync(1) -- 0 disables, 1 enables, true/false also accepted

-- Keep a responsive UI informed about OS window resizes.
local detach = Window.attach(ui)
-- Call detach() when you no longer need the resize callback.
```

`Window.setMode(width, height, options)` and `Window.configure(options)` also allow setting supported LÖVE window flags. These functions require the LÖVE runtime; the shared GUI layout calculations do not.

## Run the tests

From the project root:

```sh
lua tests/run_gui.lua
lua tests/run_gamekit.lua
lua tests/run_window.lua
lua tests/run_dock.lua
lua tests/run_camera.lua
```

## Scene lifecycle

A scene may define these methods:

- `enter(previous_scene)`
- `leave(next_scene)`
- `update(dt)`
- `draw(...)`

Switch scenes with:

```lua
GameKit.Scene.switch(next_scene)
```

## Input

Bind physical input sources to named actions:

```lua
GameKit.Input.bind("jump", "space", "controller:a")

if GameKit.Input.down("jump") then
    -- Held
end

if GameKit.Input.pressed("jump") then
    -- Newly pressed this frame
end

if GameKit.Input.released("jump") then
    -- Newly released this frame
end
```

The framework adapter forwards input events to the shared input system.

## Timers

```lua
GameKit.Timer.after(2, function()
    print("Two seconds later")
end)

GameKit.Timer.every(1, function()
    print("One-second interval")
end, 5)
```

`Timer.every` accepts an optional repetition count. Timer callbacks execute during `Timer.update(dt)`.

## Current limitations

- The supplied input action module is keyboard-focused; GUI pointer and keyboard navigation are handled separately by the GUI adapter.
- Controller and VR-specific input mappings are not implemented yet.
- Scene switching is immediate; scene stacks and transitions are future features.
- Timer pause groups and scene-owned cleanup are not implemented.
- The demos and new modules should be run through the included tests and your installed LÖVE version before being considered production-ready.
- This toolkit is currently Lua, not generated or type-checked Teal.

## Roadmap

1. Test the shared modules and both adapters.
2. Add controller and VR input abstractions.
3. Add scene stacks, pause/resume and transitions.
4. Add tweening, asset caching and debug overlays.
5. Add Teal type definitions and Teal++ syntax integration.
