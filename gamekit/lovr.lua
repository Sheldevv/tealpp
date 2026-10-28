
local Scene = require("gamekit.scene")
local Input = require("gamekit.input")
local Timer = require("gamekit.timer")

local Lovr = {}

function Lovr.install(create_scene)
    assert(type(create_scene) == "function",
        "Lovr.install expects a scene factory function")

    function lovr.load()
        Scene.switch(create_scene())
    end

    function lovr.update(dt)
        Timer.update(dt)
        Scene.update(dt)
        Input.endFrame()
    end

    function lovr.draw(pass)
        Scene.draw(pass)
    end

    function lovr.keypressed(key, scancode, repeating)
        if not repeating then
            Input.keypressed(key)
        end
    end

    function lovr.keyreleased(key)
        Input.keyreleased(key)
    end
end

return Lovr
