
package.path = "./?.lua;./?/init.lua;" .. package.path

local GameKit = require("gamekit")
local Scene = GameKit.Scene
local Input = GameKit.Input
local Timer = GameKit.Timer

local passed = 0

local function test(name, callback)
    callback()
    passed = passed + 1
    print("PASS: " .. name)
end

local function reset()
    Scene.reset()
    Input.reset()
    Timer.clear()
    Timer.update(0)
end

test("scene lifecycle and switching", function()
    reset()

    local events = {}

    local first = {
        enter = function(self, previous)
            assert(previous == nil)
            events[#events + 1] = "first:enter"
        end,

        update = function(self, dt)
            assert(dt == 0.016)
            events[#events + 1] = "first:update"
        end,

        leave = function(self, next_scene)
            assert(next_scene ~= nil)
            events[#events + 1] = "first:leave"
        end,
    }

    local second = {
        enter = function(self, previous)
            assert(previous == first)
            events[#events + 1] = "second:enter"
        end,
    }

    Scene.switch(first)
    assert(Scene.current() == first)

    Scene.update(0.016)
    Scene.switch(second)

    assert(Scene.current() == second)
    assert(table.concat(events, ",") ==
        "first:enter,first:update,first:leave,second:enter")

    reset()
end)

test("input press, hold, and release", function()
    reset()

    Input.bind("jump", "space")

    Input.keypressed("space")
    assert(Input.down("jump"))
    assert(Input.pressed("jump"))
    assert(not Input.released("jump"))

    Input.endFrame()
    assert(Input.down("jump"))
    assert(not Input.pressed("jump"))

    Input.keyreleased("space")
    assert(not Input.down("jump"))
    assert(Input.released("jump"))

    reset()
end)

test("multiple keys share one action", function()
    reset()

    Input.bind("move_left", "a", "left")

    Input.keypressed("a")
    assert(Input.pressed("move_left"))

    Input.endFrame()
    Input.keypressed("left")
    assert(Input.down("move_left"))

    Input.keyreleased("a")
    assert(Input.down("move_left"))
    assert(not Input.released("move_left"))

    Input.keyreleased("left")
    assert(not Input.down("move_left"))
    assert(Input.released("move_left"))

    reset()
end)

test("releaseAll clears held inputs", function()
    reset()

    Input.bind("move", "w", "up")

    Input.keypressed("w")
    Input.keypressed("up")
    assert(Input.down("move"))

    Input.releaseAll()

    assert(not Input.down("move"))
    assert(Input.released("move"))

    reset()
end)

test("one-shot timer fires once", function()
    reset()

    local calls = 0

    Timer.after(0.1, function()
        calls = calls + 1
    end)

    Timer.update(0.05)
    assert(calls == 0)

    Timer.update(0.05)
    assert(calls == 1)

    Timer.update(1)
    assert(calls == 1)

    reset()
end)

test("timer cancellation works", function()
    reset()

    local calls = 0

    local id = Timer.after(0.1, function()
        calls = calls + 1
    end)

    assert(Timer.cancel(id))
    assert(not Timer.cancel(id))

    Timer.update(1)
    assert(calls == 0)

    reset()
end)

test("repeating timer respects repetition count", function()
    reset()

    local calls = 0

    Timer.every(0.25, function()
        calls = calls + 1
    end, 3)

    Timer.update(1)
    assert(calls == 3)

    Timer.update(1)
    assert(calls == 3)

    reset()
end)

test("callback-created timer runs on next update", function()
    reset()

    local events = {}

    Timer.after(0, function()
        events[#events + 1] = "first"

        Timer.after(0, function()
            events[#events + 1] = "second"
        end)
    end)

    Timer.update(0)
    assert(table.concat(events, ",") == "first")

    Timer.update(0)
    assert(table.concat(events, ",") == "first,second")

    reset()
end)

test("timer callback can cancel itself", function()
    reset()

    local calls = 0
    local id

    id = Timer.every(0.1, function()
        calls = calls + 1
        Timer.cancel(id)
    end)

    Timer.update(1)
    assert(calls == 1)

    Timer.update(1)
    assert(calls == 1)

    reset()
end)

print(("%d GameKit tests passed!"):format(passed))
