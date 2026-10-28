-- TGK GUI demo — no wiring required.
-- Run: ./bin/tpp love examples/gui/main.tpp

import gamekit as GameKit

local state = {
    clicks = 0,
    pulse = true,
    t = 0.0,
}

local ui = GameKit.GUI.new({ x = 20, y = 20, w = 240 })

local counter_label = ui:label("clicks: 0")

ui:button("click me", function()
    state.clicks = state.clicks + 1
    counter_label.text = "clicks: " .. tostring(state.clicks)
end)

ui:checkbox("enable pulse", true, function(checked: boolean)
    state.pulse = checked
end)

GameKit.app({
    title = "TGK GUI demo",
    width = 800,
    height = 600,
    background = "#1a1a2e",
    gui = ui,
})

function update(dt: number)
    state.t = state.t + dt
end

function draw()
    local cx, cy = 500, 300
    local radius = 40 + math.sin(state.t * 3) * 4
    if state.pulse then
        GameKit.graphics.circle("fill", cx, cy, radius + 20, "#e9456088")
    end
    GameKit.graphics.circle("fill", cx, cy, radius, "#e94560")
    GameKit.graphics.print("gui auto-wired via GameKit.app", 20, 560, "#c0c0d0")
end
