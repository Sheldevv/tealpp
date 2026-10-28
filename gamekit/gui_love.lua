
local LoveGUI = {}

function LoveGUI.new(options)
    options = options or {}
    local font = love.graphics.newFont(options.font_size or 14)

    local scissor_stack = {}

    return {
        rect = function(_, mode, x, y, w, h, color, radius)
            love.graphics.setColor(color)
            love.graphics.rectangle(
                mode, x, y, w, h, radius or 0, radius or 0
            )
        end,

        text = function(_, value, x, y, color)
            love.graphics.setColor(color)
            love.graphics.print(tostring(value), font, x, y)
        end,

        textWidth = function(_, value)
            return font:getWidth(tostring(value))
        end,

        pushClip = function(_, x, y, w, h)
            local oldX, oldY, oldW, oldH = love.graphics.getScissor()
            scissor_stack[#scissor_stack + 1] = oldX and {oldX, oldY, oldW, oldH} or false
            if oldX then
                local left = math.max(x, oldX)
                local top = math.max(y, oldY)
                local right = math.min(x + w, oldX + oldW)
                local bottom = math.min(y + h, oldY + oldH)
                love.graphics.setScissor(left, top, math.max(0, right - left), math.max(0, bottom - top))
            else
                love.graphics.setScissor(x, y, w, h)
            end
        end,

        popClip = function()
            local previous = table.remove(scissor_stack)
            if previous then
                love.graphics.setScissor(previous[1], previous[2], previous[3], previous[4])
            else
                love.graphics.setScissor()
            end
        end,
    }
end

function LoveGUI.attach(ui)
    assert(type(ui) == "table", "ui must be a GameKit UI")

    local names = {
        "mousemoved",
        "mousepressed",
        "mousereleased",
        "textinput",
        "keypressed",
        "focus",
        "wheelmoved",
    }

    local previous = {}
    local handlers = {}

    for _, name in ipairs(names) do
        previous[name] = love[name]
    end

    handlers.mousemoved = function(x, y, dx, dy, ...)
        ui:mousemoved(x, y)
        if previous.mousemoved then
            previous.mousemoved(x, y, dx, dy, ...)
        end
    end

    handlers.mousepressed = function(x, y, button, istouch, presses, ...)
        ui:mousepressed(x, y, button)
        if previous.mousepressed then
            previous.mousepressed(x, y, button, istouch, presses, ...)
        end
    end

    handlers.mousereleased = function(x, y, button, istouch, presses, ...)
        ui:mousereleased(x, y, button)
        if previous.mousereleased then
            previous.mousereleased(x, y, button, istouch, presses, ...)
        end
    end

    handlers.textinput = function(text, ...)
        ui:handleTextInput(text)
        if previous.textinput then
            previous.textinput(text, ...)
        end
    end

    handlers.keypressed = function(key, scancode, isrepeat, ...)
        ui:keypressed(key)
        if previous.keypressed then
            previous.keypressed(key, scancode, isrepeat, ...)
        end
    end

    handlers.wheelmoved = function(x, y, ...)
        ui:wheelmoved(x, y)
        if previous.wheelmoved then previous.wheelmoved(x, y, ...) end
    end

    handlers.focus = function(focused, ...)
        if not focused then
            ui:releaseAll()
        end
        if previous.focus then
            previous.focus(focused, ...)
        end
    end

    for _, name in ipairs(names) do
        love[name] = handlers[name]
    end

    local attached = true

    return function()
        if not attached then return end
        attached = false

        for _, name in ipairs(names) do
            if love[name] == handlers[name] then
                love[name] = previous[name]
            end
        end
    end
end

return LoveGUI
