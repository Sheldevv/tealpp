-- Neon Survivor
-- WASD/arrows move, Space/J shoots, Enter restarts, Esc quits.

import gamekit as GameKit

local record GraphicsAPI
    getDimensions: function(): number, number
    clear: function(r: number, g: number, b: number, a?: number)
    setColor: function(r: number, g: number, b: number, a?: number)
    circle: function(mode: string, x: number, y: number, radius: number, segments?: integer)
    line: function(x1: number, y1: number, x2: number, y2: number)
    rectangle: function(mode: string, x: number, y: number, width: number, height: number)
    print: function(text: string, x: number, y: number, rotation?: number, sx?: number, sy?: number)
    printf: function(text: string, x: number, y: number, width: number, align: string, rotation?: number, sx?: number, sy?: number)
end

local record KeyboardAPI
    isDown: function(...: string): boolean
end

local record WindowAPI
    setMode: function(width: integer, height: integer, settings: any)
    setTitle: function(title: string)
end

local record EventAPI
    quit: function()
end

local record MouseAPI
    getPosition: function(): number, number
end

local record LoveAPI
    graphics: GraphicsAPI
    keyboard: KeyboardAPI
    window: WindowAPI
    event: EventAPI
    mouse: MouseAPI
    load: function()
    update: function(dt: number)
    draw: function()
    keypressed: function(key: string)
    resize: function(width: number, height: number)
end

global love: LoveAPI

local record Player
    x: number
    y: number
    speed: number
    radius: number
    health: number
end

local record Enemy
    x: number
    y: number
    speed: number
    radius: number
end

local record Bullet
    x: number
    y: number
    vx: number
    vy: number
    radius: number
    life: number
end

local record Particle
    x: number
    y: number
    vx: number
    vy: number
    life: number
    max_life: number
end

local SCREEN_W: number = 960
local SCREEN_H: number = 640

local player: Player = {
    x = 480,
    y = 320,
    speed = 260,
    radius = 13,
    health = 100,
}

local enemies: {Enemy} = {}
local bullets: {Bullet} = {}
local particles: {Particle} = {}

local score: number = 0
local elapsed: number = 0
local spawn_timer: number = 0
local shoot_timer: number = 0
local difficulty: number = 1
local game_over: boolean = false

local autofire: boolean = true
local difficulty_scale: number = 1
local difficulty_wave: number = 0
local difficulty_label: string = "NORMAL"

local UI_Y: number = 96

local ui = GameKit.GUI.new({
    x = SCREEN_W - 260,
    y = 20,
    w = 240,
    padding = 10,
    spacing = 6,
})

local autofire_toggle = ui:checkbox(
    "AUTOFIRE",
    true,
    function(checked: boolean)
        autofire = checked
    end
)

local difficulty_dropdown = ui:dropdown({
    items = { "EASY", "NORMAL", "HARD", "INSANE" },
    selected = 2,
    callback = function(index: integer, label: string)
        difficulty_label = label
        if index == 1 then
            difficulty_scale = 0.6
        elseif index == 2 then
            difficulty_scale = 1
        elseif index == 3 then
            difficulty_scale = 1.5
        else
            difficulty_scale = 2.2
        end
    end,
})

ui:setTooltip(autofire_toggle, "Toggle automatic target fire")
ui:setTooltip(difficulty_dropdown, "Enemy speed and spawn rate")

local renderer = GameKit.LoveGUI.new()
GameKit.LoveGUI.attach(ui)

local function distance(
    x1: number,
    y1: number,
    x2: number,
    y2: number
): number
    local dx: number = x2 - x1
    local dy: number = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function spawn_particles(x: number, y: number, count: integer)
    for _ = 1, count do
        local angle: number = math.random() * math.pi * 2
        local speed: number = math.random(35, 150)
        table.insert(particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.5,
            max_life = 0.5,
        } as Particle)
    end
end

local function spawn_enemy()
    local side: integer = math.random(1, 4)
    local x: number = 0
    local y: number = 0

    if side == 1 then
        x = -24
        y = math.random(0, math.floor(SCREEN_H))
    elseif side == 2 then
        x = SCREEN_W + 24
        y = math.random(0, math.floor(SCREEN_H))
    elseif side == 3 then
        x = math.random(0, math.floor(SCREEN_W))
        y = -24
    else
        x = math.random(0, math.floor(SCREEN_W))
        y = SCREEN_H + 24
    end

    table.insert(enemies, {
        x = x,
        y = y,
        radius = math.random(10, 16),
        speed = (math.random(45, 75) + difficulty * 5) * difficulty_scale,
    } as Enemy)
end

local function shoot()
    local nearest: Enemy | nil = nil
    local nearest_distance: number = math.huge

    for _, enemy in ipairs(enemies) do
        local d: number = distance(player.x, player.y, enemy.x, enemy.y)
        if d < nearest_distance then
            nearest = enemy
            nearest_distance = d
        end
    end

    if nearest == nil then
        return
    end

    -- Teal won't narrow the union here, so cast after the guard.
    local target = nearest as Enemy
    local dx: number = target.x - player.x
    local dy: number = target.y - player.y
    local length: number = math.sqrt(dx * dx + dy * dy)

    if length <= 0 then
        return
    end

    table.insert(bullets, {
        x = player.x,
        y = player.y,
        vx = dx / length * 520,
        vy = dy / length * 520,
        radius = 4,
        life = 1.5,
    } as Bullet)
end

local function manual_fire()
    if shoot_timer > 0 then
        return
    end
    shoot()
    shoot_timer = 0.18
end

local function reset_game()
    player.x = SCREEN_W / 2
    player.y = SCREEN_H / 2
    player.health = 100

    enemies = {}
    bullets = {}
    particles = {}

    score = 0
    elapsed = 0
    spawn_timer = 0
    shoot_timer = 0
    difficulty = 1
    difficulty_wave = 0
    game_over = false
end

function love.load()
    math.randomseed(os.time())

    love.window.setMode(960, 640, {
        resizable = true,
        vsync = 1,
    })

    love.window.setTitle("NEON SURVIVOR // T++")

    SCREEN_W, SCREEN_H = love.graphics.getDimensions()
    ui:setBounds(SCREEN_W - 260, 20, 240, UI_Y)
    reset_game()
end

function love.update(dt: number)
    ui:update(dt)

    local mouse_x, mouse_y = love.mouse.getPosition()
    ui:mousemoved(mouse_x, mouse_y)

    if game_over then
        return
    end

    elapsed = elapsed + dt
    difficulty = (1 + elapsed / 30) * difficulty_scale
    difficulty_wave = math.floor(elapsed / 15)

    local mx: number = 0
    local my: number = 0

    if love.keyboard.isDown("w", "up") then my = my - 1 end
    if love.keyboard.isDown("s", "down") then my = my + 1 end
    if love.keyboard.isDown("a", "left") then mx = mx - 1 end
    if love.keyboard.isDown("d", "right") then mx = mx + 1 end

    local movement_length: number = math.sqrt(mx * mx + my * my)

    if movement_length > 0 then
        player.x = player.x + mx / movement_length * player.speed * dt
        player.y = player.y + my / movement_length * player.speed * dt
    end

    SCREEN_W, SCREEN_H = love.graphics.getDimensions()

    player.x = math.max(player.radius, math.min(SCREEN_W - player.radius, player.x))
    player.y = math.max(player.radius, math.min(SCREEN_H - player.radius, player.y))

    spawn_timer = spawn_timer - dt
    shoot_timer = shoot_timer - dt

    if spawn_timer <= 0 then
        spawn_enemy()
        spawn_timer = math.max(0.12, (0.85 - elapsed * 0.008) / difficulty_scale)
    end

    if autofire and shoot_timer <= 0 then
        shoot()
        shoot_timer = 0.22 / math.max(1, difficulty_scale * 0.7)
    end

    -- Hold to fire manually even when autofire is off.
    if not autofire and love.keyboard.isDown("space", "j") then
        manual_fire()
    end

    for i = #enemies, 1, -1 do
        local enemy: Enemy = enemies[i]
        local dx: number = player.x - enemy.x
        local dy: number = player.y - enemy.y
        local length: number = math.sqrt(dx * dx + dy * dy)

        if length > 0 then
            enemy.x = enemy.x + dx / length * enemy.speed * dt
            enemy.y = enemy.y + dy / length * enemy.speed * dt
        end

        if distance(player.x, player.y, enemy.x, enemy.y)
            < player.radius + enemy.radius then
            player.health = player.health - 25
            spawn_particles(enemy.x, enemy.y, 12)
            table.remove(enemies, i)

            if player.health <= 0 then
                player.health = 0
                game_over = true
            end
        end
    end

    for i = #bullets, 1, -1 do
        local bullet: Bullet = bullets[i]

        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        bullet.life = bullet.life - dt

        local remove_bullet: boolean =
            bullet.life <= 0
            or bullet.x < -20
            or bullet.x > SCREEN_W + 20
            or bullet.y < -20
            or bullet.y > SCREEN_H + 20

        for j = #enemies, 1, -1 do
            local enemy: Enemy = enemies[j]

            if distance(bullet.x, bullet.y, enemy.x, enemy.y)
                < bullet.radius + enemy.radius then
                spawn_particles(enemy.x, enemy.y, 8)
                table.remove(enemies, j)
                score = score + 10
                remove_bullet = true
                break
            end
        end

        if remove_bullet then
            table.remove(bullets, i)
        end
    end

    for i = #particles, 1, -1 do
        local particle: Particle = particles[i]

        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.life = particle.life - dt
        particle.vx = particle.vx * 0.96
        particle.vy = particle.vy * 0.96

        if particle.life <= 0 then
            table.remove(particles, i)
        end
    end
end

local function draw_text(
    value: string,
    x: number,
    y: number,
    size: number,
    r: number,
    g: number,
    b: number
)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.print(value, x, y, 0, size / 12, size / 12)
end

function love.draw()
    love.graphics.clear(0.035, 0.045, 0.085, 1)

    local width: number
    local height: number
    width, height = love.graphics.getDimensions()

    love.graphics.setColor(0.12, 0.2, 0.3, 0.22)

    for x = 0, width, 40 do
        love.graphics.line(x, 0, x, height)
    end

    for y = 0, height, 40 do
        love.graphics.line(0, y, width, y)
    end

    for _, particle in ipairs(particles) do
        local alpha: number = math.max(0, particle.life / particle.max_life)
        love.graphics.setColor(0.15, 0.85, 1, alpha)
        love.graphics.circle("fill", particle.x, particle.y, 3 * alpha)
    end

    for _, bullet in ipairs(bullets) do
        love.graphics.setColor(0.2, 0.95, 1, 0.25)
        love.graphics.circle("fill", bullet.x, bullet.y, 9)

        love.graphics.setColor(0.15, 0.95, 1, 1)
        love.graphics.circle("fill", bullet.x, bullet.y, bullet.radius)
    end

    for _, enemy in ipairs(enemies) do
        love.graphics.setColor(1, 0.1, 0.4, 0.15)
        love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius * 2)

        love.graphics.setColor(1, 0.18, 0.58, 1)
        love.graphics.circle("line", enemy.x, enemy.y, enemy.radius)

        love.graphics.setColor(1, 0.3, 0.55, 0.85)
        love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius * 0.45)
    end

    love.graphics.setColor(0.1, 0.9, 1, 0.12)
    love.graphics.circle("fill", player.x, player.y, player.radius * 2.5)

    love.graphics.setColor(0.15, 0.95, 1, 1)
    love.graphics.circle("line", player.x, player.y, player.radius + 3)

    love.graphics.setColor(0.9, 0.96, 1, 1)
    love.graphics.circle("fill", player.x, player.y, player.radius)

    draw_text("NEON SURVIVOR", 20, 18, 20, 0.15, 0.95, 1)
    draw_text("SCORE  " .. tostring(score), 20, 48, 12, 0.9, 0.96, 1)
    draw_text("TIME   " .. tostring(math.floor(elapsed)) .. "s", 20, 68, 12, 0.45, 0.55, 0.7)
    draw_text("THREAT " .. tostring(math.floor(difficulty * 100)) .. "%", 20, 88, 12, 1, 0.18, 0.58)
    draw_text("WAVE   " .. tostring(difficulty_wave), 20, 108, 12, 1, 0.85, 0.25)

    love.graphics.setColor(0.15, 0.18, 0.25, 1)
    love.graphics.rectangle("fill", 20, 132, 180, 12)

    if player.health < 50 then
        love.graphics.setColor(1, 0.25, 0.4, 1)
    else
        love.graphics.setColor(0.2, 1, 0.55, 1)
    end

    love.graphics.rectangle("fill", 20, 132, 180 * player.health / 100, 12)

    draw_text("HP " .. tostring(player.health), 210, 129, 12, 0.9, 0.96, 1)
    draw_text("MODE   " .. difficulty_label, 20, 152, 12, 1, 0.85, 0.25)
    draw_text("WASD / ARROWS - MOVE", 20, height - 32, 12, 0.45, 0.55, 0.7)

    if autofire then
        draw_text("AUTOFIRE ON", width - 220, height - 32, 12, 0.15, 0.95, 1)
    else
        draw_text("SPACE / J - FIRE", width - 220, height - 32, 12, 1, 0.85, 0.25)
    end

    ui:draw(renderer)

    if game_over then
        love.graphics.setColor(0.015, 0.02, 0.05, 0.88)
        love.graphics.rectangle("fill", 0, 0, width, height)

        love.graphics.setColor(1, 0.18, 0.58, 1)
        love.graphics.printf("SYSTEM FAILURE", 0, height / 2 - 50, width, "center", 0, 2, 2)

        love.graphics.setColor(0.9, 0.96, 1, 1)
        love.graphics.printf("FINAL SCORE: " .. tostring(score), 0, height / 2 + 5, width, "center")

        love.graphics.setColor(0.15, 0.95, 1, 1)
        love.graphics.printf("PRESS ENTER TO RESTART", 0, height / 2 + 40, width, "center")
    end
end

function love.keypressed(key: string)
    if game_over and key == "return" then
        reset_game()
    end

    if key == "escape" then
        love.event.quit()
    end
end

function love.resize(width: number, height: number)
    SCREEN_W = width
    SCREEN_H = height
    ui:setBounds(width - 260, 20, 240, UI_Y)
end
