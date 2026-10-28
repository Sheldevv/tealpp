local Window = require("gamekit.window_love")
local passed = 0

local function test(name, callback)
    local ok, err = pcall(callback)
    if ok then
        passed = passed + 1
        print("PASS: " .. name)
    else
        print("FAIL: " .. name .. "\n  " .. tostring(err))
        os.exit(1)
    end
end

local function fakeLove()
    local state = {
        width = 960,
        height = 540,
        flags = {resizable = true, fullscreen = false, vsync = 1},
        title = "GameKit",
    }
    local oldLove = _G.love
    _G.love = {
        graphics = {
            getDimensions = function() return state.width, state.height end,
        },
        window = {
            getMode = function()
                local flags = {}
                for k, v in pairs(state.flags) do flags[k] = v end
                return state.width, state.height, flags, 1
            end,
            setMode = function(width, height, flags)
                state.width, state.height = width, height
                state.flags = flags
                return true
            end,
            setTitle = function(title) state.title = title end,
        },
    }
    return state, function() _G.love = oldLove end
end

test("window size reads current dimensions", function()
    local state, restore = fakeLove()
    local width, height = Window.getSize()
    assert(width == 960 and height == 540)
    restore()
end)

test("setSize preserves existing window flags", function()
    local state, restore = fakeLove()
    local width, height = Window.setSize(1280, 720)
    assert(width == 1280 and height == 720)
    assert(state.flags.resizable == true)
    assert(state.flags.vsync == 1)
    restore()
end)

test("fullscreen can be toggled", function()
    local state, restore = fakeLove()
    assert(Window.toggleFullscreen() == true)
    assert(state.flags.fullscreen == true)
    assert(Window.toggleFullscreen() == false)
    assert(state.flags.fullscreen == false)
    restore()
end)

test("minimum size enables resizing", function()
    local state, restore = fakeLove()
    assert(Window.setMinSize(640, 360) == true)
    assert(state.flags.minwidth == 640 and state.flags.minheight == 360)
    assert(state.flags.resizable == true)
    restore()
end)

test("window title updates", function()
    local state, restore = fakeLove()
    Window.setTitle("Test Window")
    assert(state.title == "Test Window")
    restore()
end)


test("borderless and VSync settings preserve other flags", function()
    local state, restore = fakeLove()
    assert(Window.setBorderless(true) == true)
    assert(state.flags.borderless == true)
    assert(state.flags.resizable == true)
    assert(Window.setVSync(false) == true)
    assert(state.flags.vsync == 0)
    restore()
end)

test("resize attachment forwards events and detaches safely", function()
    local state, restore = fakeLove()
    local oldResizeCalls = 0
    local oldResize = function() oldResizeCalls = oldResizeCalls + 1 end
    _G.love.resize = oldResize
    local receivedWidth, receivedHeight
    local ui = {
        resize = function(_, width, height)
            receivedWidth, receivedHeight = width, height
        end,
    }
    local detach = Window.attach(ui)
    _G.love.resize(1024, 768)
    assert(receivedWidth == 1024 and receivedHeight == 768)
    assert(oldResizeCalls == 1)
    detach()
    assert(_G.love.resize == oldResize)
    restore()
end)

print(("%d window tests passed!"):format(passed))
