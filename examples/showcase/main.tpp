-- TGK Showcase — graphics, input, timers, GUI, audio, assets.
-- Runs without assets present; drop assets/player.png and assets/beep.wav
-- next to this file to enable the sprite and sound.

import gamekit as GameKit

local player_img = GameKit.assets.image("assets/player.png")
local beep = GameKit.assets.sound("assets/beep.wav")

local state = {
    x = 400.0,
    y = 300.0,
    vx = 0.0,
    vy = 0.0,
    score = 0,
    t = 0.0,
    muted = false,
}

GameKit.Input.bind("up", "w", "up")
GameKit.Input.bind("down", "s", "down")
GameKit.Input.bind("left", "a", "left")
GameKit.Input.bind("right", "d", "right")

local ui = GameKit.GUI.new({ x = 20, y = 20, w = 220 })
local score_label = ui:label("score: 0")

ui:button("+10", function()
    state.score = state.score + 10
    score_label.text = "score: " .. tostring(state.score)
end)

ui:checkbox("mute", false, function(checked: boolean)
    state.muted = checked
    GameKit.audio.setMasterVolume(checked and 0.0 or 1.0)
end)

GameKit.app({
    title = "TGK Showcase",
    width = 800,
    height = 600,
    background = "#0d1117",
    gui = ui,
})

GameKit.Timer.every(1.5, function()
    state.score = state.score + 1
    score_label.text = "score: " .. tostring(state.score)
end)

function update(dt: number)
    state.t = state.t + dt

    local speed = 260.0
    if GameKit.Input.down("up") then state.vy = -speed end
    if GameKit.Input.down("down") then state.vy = speed end
    if GameKit.Input.down("left") then state.vx = -speed end
    if GameKit.Input.down("right") then state.vx = speed end
    if not GameKit.Input.down("up") and not GameKit.Input.down("down") then
        state.vy = state.vy * 0.82
    end
    if not GameKit.Input.down("left") and not GameKit.Input.down("right") then
        state.vx = state.vx * 0.82
    end

    state.x = math.max(24.0, math.min(776.0, state.x + state.vx * dt))
    state.y = math.max(24.0, math.min(576.0, state.y + state.vy * dt))
end

function draw()
    local w, h = GameKit.graphics.getDimensions()

    GameKit.graphics.setColor("#1e232e")
    for x = 0, w, 40 do GameKit.graphics.line(x, 0, x, h) end
    for y = 0, h, 40 do GameKit.graphics.line(0, y, w, y) end

    local pulse = 1.0 + math.sin(state.t * 2.0) * 0.12
    GameKit.graphics.circle("fill", w - 110, 110, 40.0 * pulse, "#3b82f6")

    if player_img then
        GameKit.graphics.image(player_img, state.x - 16.0, state.y - 16.0, 0.0, 2.0, 2.0)
    else
        local a = state.t * 2.0
        local r = 18.0
        local p1x = state.x + math.cos(a) * r
        local p1y = state.y + math.sin(a) * r
        local p2x = state.x + math.cos(a + 2.094) * r
        local p2y = state.y + math.sin(a + 2.094) * r
        local p3x = state.x + math.cos(a + 4.188) * r
        local p3y = state.y + math.sin(a + 4.188) * r
        GameKit.graphics.polygon("fill", "#22d3ee", p1x, p1y, p2x, p2y, p3x, p3y)
    end

    local mx, my = GameKit.Input.mousePosition()
    GameKit.graphics.print(
        "mouse: " .. tostring(math.floor(mx)) .. ", " .. tostring(math.floor(my)),
        20.0, h - 64.0, "#64748b"
    )
    GameKit.graphics.print(
        "WASD / arrows to move. Click to beep. Right-click to mute.",
        20.0, h - 40.0, "#64748b"
    )
end

function mousepressed(x: number, y: number, button: integer, _istouch: boolean, _presses: integer)
    if button == 2 then
        state.muted = not state.muted
        GameKit.audio.setMasterVolume(state.muted and 0.0 or 1.0)
        return
    end
    if beep and not state.muted then
        local pitch = 0.5 + (y / 600.0)
        GameKit.audio.play(beep, 0.5, pitch)
    end
    local _x = x
end
