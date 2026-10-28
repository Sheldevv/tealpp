
local GameKit = require("gamekit")

local Input = GameKit.Input
local Timer = GameKit.Timer

Input.bind("left", "a", "left")
Input.bind("right", "d", "right")
Input.bind("up", "w", "up")
Input.bind("down", "s", "down")

local GameScene = {}

function GameScene:enter()
    self.x = 480
    self.y = 270
    self.speed = 240
    self.message = "Welcome to Teal++ GameKit!"

    Timer.after(2, function()
        self.message = "Move with WASD or arrow keys."
    end)
end

function GameScene:update(dt)
    if Input.down("left") then
        self.x = self.x - self.speed * dt
    end

    if Input.down("right") then
        self.x = self.x + self.speed * dt
    end

    if Input.down("up") then
        self.y = self.y - self.speed * dt
    end

    if Input.down("down") then
        self.y = self.y + self.speed * dt
    end

    self.x = math.max(20, math.min(940, self.x))
    self.y = math.max(20, math.min(520, self.y))
end

function GameScene:draw()
    love.graphics.setColor(0.12, 0.15, 0.22)
    love.graphics.rectangle("fill", 0, 0, 960, 540)

    love.graphics.setColor(0.25, 0.8, 1)
    love.graphics.circle("fill", self.x, self.y, 20)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.message, 20, 20)
    love.graphics.print("GameKit LÖVE adapter", 20, 44)
    love.graphics.print(
        ("Position: %.0f, %.0f"):format(self.x, self.y),
        20, 68
    )
end

GameKit.Love.install(function()
    return GameScene
end)
