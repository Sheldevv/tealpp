local Input = {}

local bindings = {}
local sources_down = {}
local action_down = {}
local action_pressed = {}
local action_released = {}

local mouse_x, mouse_y = 0, 0
local mouse_buttons = {}

local function is_action_down(action)
    local sources = bindings[action]
    if not sources then return false end
    for source in pairs(sources) do
        if sources_down[source] then return true end
    end
    return false
end

local function refresh_actions()
    for action in pairs(bindings) do
        local was = action_down[action] or false
        local now = is_action_down(action)
        if now and not was then
            action_pressed[action] = true
        elseif was and not now then
            action_released[action] = true
        end
        action_down[action] = now
    end
end

function Input.bind(action, ...)
    assert(type(action) == "string" and action ~= "",
        "action must be a non-empty string")
    assert(select("#", ...) > 0,
        "bind requires at least one input source")

    bindings[action] = bindings[action] or {}
    for i = 1, select("#", ...) do
        local source = select(i, ...)
        assert(type(source) == "string" and source ~= "",
            "input source must be a non-empty string")
        bindings[action][source] = true
    end
    action_down[action] = is_action_down(action)
end

function Input.unbind(action)
    bindings[action] = nil
    action_down[action] = nil
    action_pressed[action] = nil
    action_released[action] = nil
end

function Input.down(action) return action_down[action] or false end
function Input.pressed(action) return action_pressed[action] or false end
function Input.released(action) return action_released[action] or false end

function Input.setSource(source, is_down)
    assert(type(source) == "string" and source ~= "",
        "source must be a non-empty string")
    is_down = not not is_down
    local was = sources_down[source] or false
    if was == is_down then return end
    sources_down[source] = is_down or nil
    refresh_actions()
end

function Input.keypressed(key) Input.setSource(key, true) end
function Input.keyreleased(key) Input.setSource(key, false) end

-- Mouse state
function Input.mousePosition() return mouse_x, mouse_y end

function Input.mouseDown(button)
    if button == nil then
        for _, _ in pairs(mouse_buttons) do return true end
        return false
    end
    return mouse_buttons[button] or false
end

function Input.mouseMoved(x, y)
    mouse_x, mouse_y = x, y
end

function Input.mousePressed(x, y, button)
    mouse_x, mouse_y = x, y
    mouse_buttons[button] = true
    Input.setSource("mouse:" .. tostring(button), true)
end

function Input.mouseReleased(x, y, button)
    mouse_x, mouse_y = x, y
    mouse_buttons[button] = nil
    Input.setSource("mouse:" .. tostring(button), false)
end

function Input.releaseAll()
    for source in pairs(sources_down) do
        sources_down[source] = nil
    end
    for button in pairs(mouse_buttons) do
        mouse_buttons[button] = nil
    end
    refresh_actions()
end

function Input.endFrame()
    action_pressed = {}
    action_released = {}
end

function Input.reset()
    bindings = {}
    sources_down = {}
    action_down = {}
    action_pressed = {}
    action_released = {}
    mouse_buttons = {}
    mouse_x, mouse_y = 0, 0
end

return Input
