local Window = {}

local function api()
    assert(type(love) == "table" and type(love.window) == "table",
        "GameKit.Window requires the LÖVE window API")
    return love.window
end

local function validSize(width, height)
    assert(type(width) == "number" and width == width and width > 0 and width < math.huge,
        "width must be a positive finite number")
    assert(type(height) == "number" and height == height and height > 0 and height < math.huge,
        "height must be a positive finite number")
end

local function copyFlags(flags)
    local result = {}
    for key, value in pairs(flags or {}) do result[key] = value end
    return result
end

function Window.getSize()
    assert(type(love) == "table" and type(love.graphics) == "table"
        and type(love.graphics.getDimensions) == "function",
        "GameKit.Window.getSize requires love.graphics.getDimensions")
    return love.graphics.getDimensions()
end

function Window.getMode()
    return api().getMode()
end

function Window.setMode(width, height, options)
    validSize(width, height)
    local window = api()
    local _, _, currentFlags = window.getMode()
    local flags = copyFlags(currentFlags)
    for key, value in pairs(options or {}) do flags[key] = value end
    local ok, message = window.setMode(width, height, flags)
    if ok == false then return false, message end
    return true
end

function Window.setSize(width, height)
    local _, _, flags = Window.getMode()
    local ok, message = Window.setMode(width, height, flags)
    if not ok then return false, message end
    return Window.getSize()
end

function Window.setTitle(title)
    assert(type(title) == "string", "window title must be a string")
    return api().setTitle(title)
end

function Window.setResizable(resizable)
    assert(type(resizable) == "boolean", "resizable must be a boolean")
    local width, height, flags = Window.getMode()
    flags = copyFlags(flags)
    flags.resizable = resizable
    return Window.setMode(width, height, flags)
end

function Window.setMinSize(width, height)
    validSize(width, height)
    local currentWidth, currentHeight, flags = Window.getMode()
    flags = copyFlags(flags)
    flags.minwidth = math.floor(width)
    flags.minheight = math.floor(height)
    flags.resizable = true
    return Window.setMode(currentWidth, currentHeight, flags)
end

function Window.setFullscreen(enabled, mode)
    assert(type(enabled) == "boolean", "fullscreen must be a boolean")
    local width, height, flags = Window.getMode()
    flags = copyFlags(flags)
    flags.fullscreen = enabled
    if mode then flags.fullscreentype = mode end
    return Window.setMode(width, height, flags)
end

function Window.toggleFullscreen(mode)
    local _, _, flags = Window.getMode()
    local enabled = not (flags and flags.fullscreen)
    local ok, message = Window.setFullscreen(enabled, mode)
    if not ok then return false, message end
    return enabled
end


function Window.setBorderless(enabled)
    assert(type(enabled) == "boolean", "borderless must be a boolean")
    local width, height, flags = Window.getMode()
    flags = copyFlags(flags)
    flags.borderless = enabled
    return Window.setMode(width, height, flags)
end

function Window.isFullscreen()
    local _, _, flags = Window.getMode()
    return flags and flags.fullscreen == true or false
end

function Window.setVSync(value)
    assert(type(value) == "number" or type(value) == "boolean",
        "vsync must be a number or boolean")
    local width, height, flags = Window.getMode()
    flags = copyFlags(flags)
    flags.vsync = value == true and 1 or value == false and 0 or value
    return Window.setMode(width, height, flags)
end

function Window.configure(options)
    options = options or {}
    local width, height, flags = Window.getMode()
    width = options.width or width
    height = options.height or height
    local newFlags = copyFlags(flags)
    for key, value in pairs(options) do
        if key ~= "width" and key ~= "height" and key ~= "title" then
            newFlags[key] = value
        end
    end
    local ok, message = Window.setMode(width, height, newFlags)
    if not ok then return false, message end
    if options.title then Window.setTitle(options.title) end
    return true
end

function Window.attach(ui)
    assert(type(ui) == "table" and type(ui.resize) == "function",
        "Window.attach expects a GameKit UI with resize(width, height)")
    local previous = love.resize
    local handler = function(width, height, ...)
        ui:resize(width, height)
        if previous then previous(width, height, ...) end
    end
    love.resize = handler
    local attached = true
    return function()
        if not attached then return end
        attached = false
        if love.resize == handler then love.resize = previous end
    end
end

return Window
