
local GUI = require("gamekit.gui")
local LoveGUI = require("gamekit.gui_love")
local Window = require("gamekit.window_love")

local ui
local renderer
local detachUI
local detachWindow

local playerName = "Sheldi"
local volume = 0.70
local fullscreen = false
local resizable = true
local loading = 0.35
local message = "Welcome to GameKit!"

function love.load()
    ui = GUI.new({
        x = 32,
        y = 28,
        w = 380,
        padding = 16,
        spacing = 9,
        responsive = true,
        right_margin = 32,
        min_width = 300,
        max_width = 520,

        theme = {
            background = {0.07, 0.08, 0.12, 0.98},
            foreground = {0.94, 0.95, 1, 1},
            muted = {0.55, 0.59, 0.68, 1},
            accent = {0.35, 0.62, 1, 1},
            border = {0.25, 0.29, 0.38, 1},
            surface = {0.13, 0.16, 0.22, 1},
            surface_hover = {0.19, 0.24, 0.34, 1},
            surface_pressed = {0.10, 0.13, 0.19, 1},
            track = {0.20, 0.23, 0.30, 1},
            radius = 7,
        },
    })

    ui:label("GAMEKIT", {
        height = 28,
        color = {0.45, 0.72, 1, 1},
    })

    ui:label("Milestone 5: layouts + window controls", {height = 22})
    ui:separator()

    ui:label("Player name")
    ui:textinput(playerName, function(value)
        playerName = value
        message = "Player name updated!"
    end, {
        placeholder = "Enter your name...",
        max_length = 24,
    })

    ui:label("Audio")
    ui:slider(volume, 0, 1, function(value)
        volume = value
        message = ("Volume: %d%%"):format(math.floor(value * 100 + 0.5))
    end, {
        label = "Master volume",
        step = 0.05,
    })

    ui:label("Window management")
    local windowPanel = ui:container({
        height = 150,
        padding = 8,
        spacing = 6,
        scrollable = true,
    })

    windowPanel:button("Resize to 1280 × 720", function()
        local width, height = Window.setSize(1280, 720)
        if width == false then
            message = "Resize failed: " .. tostring(height)
        else
            message = ("Window size: %d × %d"):format(width, height)
        end
    end)

    windowPanel:checkbox("Fullscreen mode", fullscreen, function(value)
        local ok, err = Window.setFullscreen(value)
        if ok then
            fullscreen = value
            message = value and "Fullscreen enabled" or "Fullscreen disabled"
        else
            fullscreen = not value
            message = "Fullscreen failed: " .. tostring(err)
        end
    end)

    windowPanel:checkbox("Resizable window", resizable, function(value)
        local ok, err = Window.setResizable(value)
        if ok then
            resizable = value
            message = value and "Window resizing enabled" or "Window resizing disabled"
        else
            resizable = not value
            message = "Resize setting failed: " .. tostring(err)
        end
    end)

    windowPanel:button("Toggle borderless", function()
        local _, _, flags = Window.getMode()
        local enabled = not (flags and flags.borderless)
        local ok, err = Window.setBorderless(enabled)
        message = ok and (enabled and "Borderless enabled" or "Borderless disabled")
            or ("Borderless failed: " .. tostring(err))
    end)

    ui:separator()

    ui:label("Loading progress")
    local progress = ui:progressbar(loading)

    ui:button("Advance progress", function()
        loading = math.min(1, loading + 0.1)
        ui:setProgress(progress, loading)

        if loading >= 1 then
            message = "Loading complete! 🎉"
        else
            message = ("Loading: %d%%"):format(loading * 100)
        end
    end)

    ui:button("Reset progress", function()
        loading = 0
        ui:setProgress(progress, loading)
        message = "Progress reset"
    end, {
        background = {0.22, 0.15, 0.19, 1},
    })

    ui:separator()

    ui:button("Say hello", function()
        message = "Hello, " .. playerName .. "!"
    end)

    renderer = LoveGUI.new({font_size = 14})
    detachUI = LoveGUI.attach(ui)
    detachWindow = Window.attach(ui)
end

function love.update(dt)
    ui:update(dt)
end

function love.draw()
    love.graphics.clear(0.035, 0.04, 0.065, 1)
    ui:draw(renderer)

    love.graphics.setColor(0.92, 0.94, 1, 1)
    love.graphics.print(message, 32, ui.y + ui.h + 18)

    love.graphics.setColor(0.58, 0.62, 0.70, 1)
    love.graphics.print(
        "Resize the window • Scroll the window-controls panel • Type in text fields",
        32,
        ui.y + ui.h + 42
    )
end

function love.quit()
    if detachUI then detachUI() end
    if detachWindow then detachWindow() end
end
