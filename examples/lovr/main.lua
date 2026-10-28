
local GameKit = require("gamekit")

local Input = GameKit.Input
local Timer = GameKit.Timer

Input.bind("left", "a", "left")
Input.bind("right", "d", "right")

local GameScene = {}

function GameScene:enter()
    self.x = 0
    self.speed = 1.5
    self.message = "Welcome to GameKit for LÖVR!"

    lovr.graphics.setBackgroundColor(0.04, 0.06, 0.1)

    Timer.after(2, function()
        self.message = "Move the cube with A/D or arrow keys."
    end)
end

function GameScene:update(dt)
    if Input.down("left") then
        self.x = self.x - self.speed * dt
    end

    if Input.down("right") then
        self.x = self.x + self.speed * dt
    end

    self.x = math.max(-2, math.min(2, self.x))
end

function GameScene:draw(pass)
    pass:setColor(0.2, 0.75, 1)
    pass:cube(self.x, 1.5, -3, 0.5)

    pass:setColor(1, 1, 1)
    pass:text(self.message, -1.5, 2.5, -3, 0.2)
end

GameKit.Lovr.install(function()
    return GameScene
end)
