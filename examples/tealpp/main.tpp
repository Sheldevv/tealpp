-- GameKit + Teal++ application example.
-- Compile with: ../../bin/tpp --program main.tpp -o main.tl
-- Then run: tl gen main.tl && love .

local record LoveCallbacks
    load: function()
    update: function(dt: number)
    draw: function()
    resize: function(width: number, height: number)
    quit: function()
end

global love: LoveCallbacks

import gamekit as GameKit

local ui = GameKit.GUI.new({
    width = 440,
    padding = 16,
    spacing = 10,
    theme = GameKit.GUI.themes.dark,
})

local renderer = GameKit.LoveGUI.new({ font_size = 16 })

ui:label("Hello from Teal++ + GameKit!")
ui:label("Choose a graphics preset:")

local quality = ui:dropdown({
    items = {"Fast", "Balanced", "Pretty"},
    selected = 2,
    callback = function(index, label)
        print("Preset selected:", index, label)
    end,
})

ui:setTooltip(quality, "Choose the rendering preset.")

ui:button("Launch", function()
    print("Game started!")
end)

ui:checkbox("Enable effects", true, function(enabled)
    print("Effects enabled:", enabled)
end)

local detachGUI = function() end

function love.load()
    detachGUI = GameKit.LoveGUI.attach(ui)
end

function love.update(dt: number)
    GameKit.Timer.update(dt)
end

function love.draw()
    ui:draw(renderer)
end

function love.resize(width: number, height: number)
    ui:resize(width, height)
end

function love.quit()
    if detachGUI then
        detachGUI()
    end
end
