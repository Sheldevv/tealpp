-- tests/run_app.lua — runs with plain `lua`, no LÖVE needed.
package.path = "./?.lua;./?/init.lua;" .. package.path

local last_mode, last_title, last_clear, last_color, last_circle
love = {
    graphics = {
        clear = function(r, g, b, a) last_clear = { r, g, b, a } end,
        setColor = function(r, g, b, a) last_color = { r, g, b, a } end,
        circle = function(mode, x, y, r, seg) last_circle = { mode, x, y, r, seg } end,
        rectangle = function() end,
        line = function() end,
        print = function() end,
        push = function() end, pop = function() end,
        translate = function() end, scale = function() end, rotate = function() end,
        getDimensions = function() return 960, 640 end,
        newFont = function(size) return { getWidth = function() return 0 end, getHeight = function() return 0 end } end,
    },
    window = {
        setMode = function(w, h, opts) last_mode = { w, h, opts } end,
        setTitle = function(t) last_title = t end,
    },
    keyboard = { isDown = function() return false end },
    mouse = { getPosition = function() return 0, 0 end },
    event = { quit = function() end },
}

local App = require("gamekit.app")
local Graphics = require("gamekit.graphics")

-- 1. app() returns handle + applies title/mode
local a = App({ title = "T", width = 320, height = 240, resizable = false, vsync = 0 })
assert(a, "app() must return handle")
love.load()
assert(last_title == "T", "title not applied: " .. tostring(last_title))
assert(last_mode and last_mode[1] == 320 and last_mode[2] == 240, "mode not applied")
assert(last_mode[3].resizable == false and last_mode[3].vsync == 0, "flags not applied")

-- 2. config.update is called
local n = 0
App({ width = 100, height = 100, update = function(dt) n = n + 1 end })
love.update(0.016); love.update(0.016)
assert(n == 2, "update should be called twice, got " .. n)

-- 3. config.draw is called
local d = 0
App({ width = 100, height = 100, draw = function() d = d + 1 end })
love.draw()
assert(d == 1, "draw should be called once")

-- 4. global update/draw dispatch
local gu, gd = 0, 0
_G.update = function(dt) gu = gu + 1 end
_G.draw = function() gd = gd + 1 end
App({ width = 100, height = 100 })
love.update(0.016); love.draw()
assert(gu == 1, "global update should be called, got " .. gu)
assert(gd == 1, "global draw should be called, got " .. gd)
_G.update = nil; _G.draw = nil

-- 5. graphics.clear parses hex
Graphics.clear("#ff0000")
assert(last_clear and last_clear[1] == 1 and last_clear[2] == 0, "clear hex parse failed")

-- 6. graphics.circle sets color
Graphics.circle("fill", 10, 20, 5, "#00ff00")
assert(last_color and last_color[1] == 0 and last_color[2] == 1, "circle color parse failed")
assert(last_circle and last_circle[1] == "fill" and last_circle[4] == 5, "circle args wrong")

-- 7. error isolation — bad callback is logged via on_error, cycle continues
local errSeen = nil
App({
    width = 100, height = 100,
    on_error = function(msg) errSeen = msg end,
    update = function(dt) error("boom") end,
})
love.update(0.016)
assert(errSeen and errSeen:find("boom"), "onError should catch callback failure")

-- 8. REGRESSION: missing `load` must not fall through to Lua builtin `load`
local crashed = nil
App({
    width = 100, height = 100,
    on_error = function(msg) crashed = msg end,
})
love.load()
assert(crashed == nil, "empty load() must not dispatch to builtin load, got: " .. tostring(crashed))

-- 9. config.load receives the config table
local load_cfg = nil
App({
    width = 200, height = 150,
    load = function(c) load_cfg = c end,
})
love.load()
assert(load_cfg and load_cfg.width == 200, "config.load should receive config table")

-- 10. wheelmoved + textinput dispatch to config
local wheel_seen, text_seen
App({
    width = 100, height = 100,
    wheelmoved = function(x, y) wheel_seen = { x, y } end,
    textinput = function(t) text_seen = t end,
})
love.wheelmoved(3, -4)
assert(wheel_seen and wheel_seen[1] == 3 and wheel_seen[2] == -4, "config.wheelmoved dispatch failed")
love.textinput("abc")
assert(text_seen == "abc", "config.textinput dispatch failed")

-- 11. GUI auto-attach via config.gui + auto-draw
local stub_ui = {
    widgets = {},
    mousemoved = function(self, x, y) self._got_mm = { x, y } end,
    mousepressed = function(self, x, y, b) self._got_mp = { x, y, b } end,
    mousereleased = function(self, x, y, b) self._got_mr = { x, y, b } end,
    handleTextInput = function(self, text) self._got_ti = text end,
    keypressed = function(self, key) self._got_kp = key end,
    wheelmoved = function(self, x, y) self._got_wheel = { x, y } end,
    releaseAll = function(self) self._got_release = true end,
    update = function(self, dt) self._got_update = dt end,
    draw = function(self, r) self._got_draw = true end,
}

App({ gui = stub_ui, width = 100, height = 100 })
love.load()

love.update(0.02)
assert(stub_ui._got_update == 0.02, "GUI update not called via config.gui")

love.mousemoved(10, 20, 0, 0)
assert(stub_ui._got_mm and stub_ui._got_mm[1] == 10, "GUI mousemoved not called")

love.textinput("hi")
assert(stub_ui._got_ti == "hi", "GUI textinput not called")

love.wheelmoved(1, 2)
assert(stub_ui._got_wheel and stub_ui._got_wheel[1] == 1, "GUI wheelmoved not called")

love.keypressed("a")
assert(stub_ui._got_kp == "a", "GUI keypressed not called")

love.focus(false)
assert(stub_ui._got_release, "GUI releaseAll not called on focus loss")

love.draw()
assert(stub_ui._got_draw, "GUI auto-draw did not fire")

-- 12. raw love global remains accessible for advanced use
assert(_G.love and _G.love.graphics, "raw love must remain accessible")
assert(type(_G.love.graphics.clear) == "function", "raw love.graphics.clear must remain")

print("OK: run_app")
