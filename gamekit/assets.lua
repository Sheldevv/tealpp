-- gamekit/assets.lua
-- Asset loader with cache. Missing files log once and return nil so games
-- can degrade gracefully instead of crashing on startup.

local Assets = {}

local cache = {
    images = {},
    fonts = {},
    sounds = {},
    music = {},
}

local function checkLove()
    if not love or not love.graphics then
        error("GameKit.assets requires LÖVE", 2)
    end
end

local function exists(path)
    if not love.filesystem then return false end
    if love.filesystem.getInfo then
        return love.filesystem.getInfo(path) ~= nil
    end
    if love.filesystem.exists then
        return love.filesystem.exists(path)
    end
    return false
end

function Assets.image(path)
    checkLove()
    if type(path) ~= "string" then error("Assets.image: path must be a string", 2) end
    local cached = cache.images[path]
    if cached ~= nil then return cached or nil end

    if not exists(path) then
        io.stderr:write("GameKit.assets: image not found: " .. path .. "\n")
        cache.images[path] = false
        return nil
    end

    local ok, img = pcall(love.graphics.newImage, path)
    if not ok then
        io.stderr:write("GameKit.assets: failed to load image " .. path .. ": " .. tostring(img) .. "\n")
        cache.images[path] = false
        return nil
    end
    cache.images[path] = img
    return img
end

function Assets.font(path, size)
    checkLove()
    -- Allow Assets.font(24) to mean "default font at 24"
    if type(path) == "number" and size == nil then
        size = path
        path = nil
    end
    size = size or 16

    local key = tostring(path or "") .. "|" .. tostring(size)
    local cached = cache.fonts[key]
    if cached ~= nil then return cached or nil end

    local ok, font
    if path == nil or path == "" then
        ok, font = pcall(love.graphics.newFont, size)
    elseif not exists(path) then
        io.stderr:write("GameKit.assets: font not found: " .. path .. ", using default\n")
        ok, font = pcall(love.graphics.newFont, size)
    else
        ok, font = pcall(love.graphics.newFont, path, size)
    end

    if not ok then
        io.stderr:write("GameKit.assets: failed to load font " .. tostring(path) .. ": " .. tostring(font) .. "\n")
        cache.fonts[key] = false
        return nil
    end
    cache.fonts[key] = font
    return font
end

function Assets.sound(path)
    checkLove()
    if not love.audio then error("Assets.sound requires love.audio", 2) end
    if type(path) ~= "string" then error("Assets.sound: path must be a string", 2) end

    local cached = cache.sounds[path]
    if cached ~= nil then return cached or nil end

    if not exists(path) then
        io.stderr:write("GameKit.assets: sound not found: " .. path .. "\n")
        cache.sounds[path] = false
        return nil
    end

    local ok, src = pcall(love.audio.newSource, path, "static")
    if not ok then
        io.stderr:write("GameKit.assets: failed to load sound " .. path .. ": " .. tostring(src) .. "\n")
        cache.sounds[path] = false
        return nil
    end
    cache.sounds[path] = src
    return src
end

function Assets.music(path)
    checkLove()
    if not love.audio then error("Assets.music requires love.audio", 2) end
    if type(path) ~= "string" then error("Assets.music: path must be a string", 2) end

    local cached = cache.music[path]
    if cached ~= nil then return cached or nil end

    if not exists(path) then
        io.stderr:write("GameKit.assets: music not found: " .. path .. "\n")
        cache.music[path] = false
        return nil
    end

    local ok, src = pcall(love.audio.newSource, path, "stream")
    if not ok then
        io.stderr:write("GameKit.assets: failed to load music " .. path .. ": " .. tostring(src) .. "\n")
        cache.music[path] = false
        return nil
    end
    cache.music[path] = src
    return src
end

function Assets.clear()
    cache.images = {}
    cache.fonts = {}
    cache.sounds = {}
    cache.music = {}
end

return Assets
