-- Copy this file to main.lua (along with conf.lua) to run the advanced demo.
local GUI = require("gamekit.gui")
local LoveGUI = require("gamekit.gui_love")
local Dock = require("gamekit.dock")
local Camera = require("gamekit.camera")

local dock, renderer, camera, detach
local status = "Drag panel headers; resize from the bottom-right corner."
local zoom = 1

function love.load()
    renderer = LoveGUI.new({font_size = 13})
    dock = Dock.new({x = 18, y = 18, width = love.graphics.getWidth() - 36, height = love.graphics.getHeight() - 36})
    camera = Camera.new({x = 0, y = 0, zoom = 1, viewport_x = 300, viewport_y = 70, viewport_w = math.max(120, love.graphics.getWidth() - 330), viewport_h = math.max(100, love.graphics.getHeight() - 120)})

    local tools = GUI.new({x = 0, y = 0, w = 250, padding = 12, spacing = 7})
    tools:label("GAMEKIT / MILESTONE 6–8")
    tools:separator()
    tools:label("Difficulty")
    tools:radio("Chill", true, function() status = "Difficulty: Chill" end, {group = "difficulty"})
    tools:radio("Normal", false, function() status = "Difficulty: Normal" end, {group = "difficulty"})
    tools:radio("Hardcore", false, function() status = "Difficulty: Hardcore" end, {group = "difficulty"})
    tools:label("Zoom")
    tools:slider(zoom, 0.5, 3, function(value)
        zoom = value
        camera:setZoom(value)
        status = ("Camera zoom: %.2fx"):format(value)
    end, {step = 0.1, label = "Viewport zoom"})
    local quality = tools:dropdown({items = {"Fast", "Balanced", "Pretty"}, selected = 2, callback = function(_, value) status = "Quality: " .. tostring(value) end})
    tools:setTooltip(quality, "Choose the rendering quality.")
    tools:button("Reset camera", function()
        camera:setPosition(0, 0):setZoom(1)
        zoom = 1
        status = "Camera reset"
    end)
    dock:add("tools", {title = "Inspector / Controls", x = 28, y = 28, w = 275, h = 390, content = tools})

    local scene = GUI.new({x = 0, y = 0, w = 400, padding = 10, spacing = 6})
    scene:label("Scene panel")
    scene:label("The dock manager handles panel movement and resizing.")
    scene:button("Toggle this panel's collapse", function() dock:toggleCollapsed("scene") end)
    dock:add("scene", {title = "Scene Hierarchy", x = 330, y = 80, w = 310, h = 180, content = scene})
    dock:add("log", {title = "Output", x = 330, y = 290, w = 310, h = 120})
    detach = LoveGUI.attach(dock)
end

function love.resize(w, h)
    if dock then dock:resize(math.max(200, w - 36), math.max(150, h - 36)) end
    if camera then camera:setViewport(300, 70, math.max(120, w - 330), math.max(100, h - 120)) end
end

function love.draw()
    love.graphics.clear(0.035, 0.04, 0.065, 1)
    local vw, vh = camera.viewport_w, camera.viewport_h
    love.graphics.setColor(0.12, 0.14, 0.19, 1)
    love.graphics.rectangle("fill", camera.viewport_x, camera.viewport_y, vw, vh, 8, 8)
    love.graphics.setScissor(camera.viewport_x, camera.viewport_y, vw, vh)
    camera:attachLove()
    love.graphics.setColor(0.28, 0.32, 0.42, 1)
    for x = -1000, 1000, 40 do
        love.graphics.line(x, -1000, x, 1000)
        love.graphics.line(-1000, x, 1000, x)
    end
    love.graphics.setColor(0.35, 0.62, 1, 1)
    love.graphics.circle("line", 0, 0, 42)
    love.graphics.rectangle("line", 90, -45, 90, 90, 6, 6)
    love.graphics.setColor(0.95, 0.55, 0.28, 1)
    love.graphics.polygon("line", -130, 60, -80, 120, -180, 120)
    camera:detachLove()
    love.graphics.setScissor()
    dock:draw(renderer)
    love.graphics.setColor(0.9, 0.92, 1, 1)
    love.graphics.print(status, 20, love.graphics.getHeight() - 24)
end

function love.quit()
    if detach then detach() end
end
