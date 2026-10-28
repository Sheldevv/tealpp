-- gamekit/app.lua
-- Zero-boilerplate application entry point.

local App = {}
local AppMT = {}
AppMT.__index = App

local function isFn(v) return type(v) == "function" end

local BASELINE = {}
for k, v in pairs(_G) do BASELINE[k] = v end

local function userDefinedGlobal(name)
    local v = _G[name]
    if v == nil then return nil end
    if BASELINE[name] == v then return nil end
    return v
end

local function mergeConfig(user)
    local c = {
        title = "TGK Game",
        width = 800,
        height = 600,
        resizable = true,
        vsync = 1,
        background = {0.02, 0.03, 0.06, 1},
        clearOnDraw = true,
    }
    if user then for k, v in pairs(user) do c[k] = v end end
    return c
end

local function parseColor(c)
    if c == nil then return nil end
    if type(c) == "table" then return c end
    if type(c) == "string" then
        local h = c:gsub("^#", "")
        if #h == 6 then
            return { tonumber(h:sub(1,2),16)/255, tonumber(h:sub(3,4),16)/255, tonumber(h:sub(5,6),16)/255, 1 }
        elseif #h == 8 then
            return { tonumber(h:sub(1,2),16)/255, tonumber(h:sub(3,4),16)/255, tonumber(h:sub(5,6),16)/255, tonumber(h:sub(7,8),16)/255 }
        end
    end
    error("GameKit.app: invalid color " .. tostring(c))
end

local function reportErr(self, name, err)
    local Errors = require("gamekit.errors")
    local msg = ("GameKit.app: error in %s callback:\n%s"):format(name, Errors.traceback(err))
    if isFn(self.on_error) then
        pcall(self.on_error, msg, err)
    else
        io.stderr:write(msg .. "\n")
    end
end

local function dispatch(self, name, ...)
    local cfgFn = self.config[name]
    if isFn(cfgFn) then
        local ok, err = pcall(cfgFn, ...)
        if not ok then reportErr(self, name, err) end
        return true
    end
    local gFn = userDefinedGlobal(name)
    if isFn(gFn) then
        local ok, err = pcall(gFn, ...)
        if not ok then reportErr(self, name, err) end
        return true
    end
    return false
end

local active_app = nil

function App.new(userConfig)
    local cfg = mergeConfig(userConfig)
    return setmetatable({
        config = cfg,
        started = false,
        on_error = cfg.on_error,
        _gui_detach = nil,
        _gui_renderer = nil,
    }, AppMT)
end

function App:onError(fn)
    assert(isFn(fn), "onError expects a function")
    self.on_error = fn
    return self
end

function App:stop()
    if self._gui_detach then
        self._gui_detach()
        self._gui_detach = nil
    end
    if love and love.event and love.event.quit then love.event.quit() end
    return self
end

local function applyWindowConfig(config)
    if not love then return end
    if love.window and love.window.setMode then
        love.window.setMode(config.width, config.height, {
            resizable = config.resizable,
            vsync = config.vsync,
        })
    end
    if love.window and love.window.setTitle then
        love.window.setTitle(config.title)
    end
end

function App:start()
    if self.started then return self end
    self.started = true

    if active_app and active_app ~= self and active_app._gui_detach then
        active_app._gui_detach()
        active_app._gui_detach = nil
    end
    active_app = self

    local config = self.config

    local Scene = require("gamekit.scene")
    local Input = require("gamekit.input")
    local Timer = require("gamekit.timer")
    local Audio = require("gamekit.audio")

    local previousLoad = love.load
    love.load = function(...)
        applyWindowConfig(config)
        dispatch(self, "load", config)
        if previousLoad then previousLoad(...) end
    end

    love.update = function(dt)
        Timer.update(dt)
        Audio.update(dt)
        Scene.update(dt)
        if config.gui and config.gui.update then config.gui:update(dt) end
        dispatch(self, "update", dt)
        Input.endFrame()
    end

    love.draw = function()
        if config.clearOnDraw and love.graphics and love.graphics.clear then
            local bg = parseColor(config.background)
            if bg then love.graphics.clear(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 1) end
        end
        Scene.draw()
        dispatch(self, "draw")
        if self._gui_renderer then config.gui:draw(self._gui_renderer) end
    end

    love.keypressed = function(key, scancode, isrepeat)
        if not isrepeat then Input.keypressed(key) end
        dispatch(self, "keypressed", key, scancode, isrepeat)
    end

    love.keyreleased = function(key)
        Input.keyreleased(key)
        dispatch(self, "keyreleased", key)
    end

    love.mousepressed = function(x, y, button, istouch, presses)
        Input.mousePressed(x, y, button)
        dispatch(self, "mousepressed", x, y, button, istouch, presses)
    end

    love.mousereleased = function(x, y, button, istouch, presses)
        Input.mouseReleased(x, y, button)
        dispatch(self, "mousereleased", x, y, button, istouch, presses)
    end

    love.mousemoved = function(x, y, dx, dy, istouch)
        Input.mouseMoved(x, y)
        dispatch(self, "mousemoved", x, y, dx, dy, istouch)
    end

    love.wheelmoved = function(x, y)
        dispatch(self, "wheelmoved", x, y)
    end

    love.textinput = function(text)
        dispatch(self, "textinput", text)
    end

    love.resize = function(w, h)
        dispatch(self, "resize", w, h)
    end

    love.focus = function(focused)
        if not focused then Input.releaseAll() end
        dispatch(self, "focus", focused)
    end

    love.quit = function()
        local fn = config.quit
        if isFn(fn) then
            local ok, res = pcall(fn)
            if ok and res == true then return true end
        end
        return false
    end

    if config.gui then
        local LoveGUI = require("gamekit.gui_love")
        self._gui_detach = LoveGUI.attach(config.gui)
        if config.gui_draw ~= false then
            self._gui_renderer = config.gui_renderer or LoveGUI.new()
        end
    end

    return self
end

setmetatable(App, { __call = function(_, cfg) return App.new(cfg):start() end })

return App
