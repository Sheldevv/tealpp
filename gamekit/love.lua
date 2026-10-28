
local Scene = require("gamekit.scene")
local Input = require("gamekit.input")
local Timer = require("gamekit.timer")

local Love = {}

function Love.install(create_scene)
    assert(type(create_scene) == "function",
        "Love.install expects a scene factory function")

    function love.load()
        Scene.switch(create_scene())
    end

    function love.update(dt)
        Timer.update(dt)
        Scene.update(dt)
        Input.endFrame()
    end

    function love.draw()
        Scene.draw()
    end

    function love.keypressed(key, scancode, isrepeat)
        if not isrepeat then
            Input.keypressed(key)
        end
    end

    function love.keyreleased(key)
        Input.keyreleased(key)
    end

    function love.focus(focused)
        if not focused then
            Input.releaseAll()
        end
    end
end

return Love
