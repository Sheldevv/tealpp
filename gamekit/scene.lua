
local Scene = {}

local active = nil

local function validate(scene)
    assert(
        scene == nil or type(scene) == "table",
        "scene must be a table or nil"
    )
end

function Scene.switch(next_scene)
    validate(next_scene)

    if active == next_scene then
        return
    end

    local previous = active
    active = next_scene

    if previous and previous.leave then
        previous:leave(next_scene)
    end

    if active and active.enter then
        active:enter(previous)
    end
end

function Scene.current()
    return active
end

function Scene.update(dt)
    local scene = active

    if scene and scene.update then
        scene:update(dt)
    end
end

function Scene.draw(...)
    local scene = active

    if scene and scene.draw then
        scene:draw(...)
    end
end

function Scene.reset()
    Scene.switch(nil)
end

return Scene
