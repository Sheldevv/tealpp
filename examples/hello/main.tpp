-- Minimal TGK demo. Run with:
--   ./bin/tpp love examples/hello/main.tpp

import gamekit as GameKit

GameKit.app({
    title = "My First Game",
    width = 960,
    height = 640,
    background = "#0b0d18",
})

function update(dt: number)
end

function draw()
    local w, h = GameKit.graphics.getDimensions()
    GameKit.graphics.circle("fill", w / 2, h / 2, 48, "#15f5ff")
    GameKit.graphics.print("hello, tgk", 20, 20, "#ffffff")
end
