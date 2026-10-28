-- gamekit/audio.lua
-- Sound playback with fades. `setMasterVolume` uses love.audio's built-in
-- master so it retroactively affects everything currently playing.

local Audio = {}

local playing = {}
local fades = {}
local current_music = nil

local function checkLove()
    if not love or not love.audio then
        error("GameKit.audio requires LÖVE", 2)
    end
end

function Audio.play(sound, volume, pitch)
    checkLove()
    if not sound then return nil end
    local src = sound:clone()
    src:setVolume(volume or 1)
    if pitch then src:setPitch(pitch) end
    src:play()
    playing[#playing + 1] = src
    return src
end

function Audio.playMusic(sound, volume)
    checkLove()
    if not sound then return nil end
    Audio.stopMusic()
    sound:setLooping(true)
    sound:setVolume(volume or 1)
    sound:play()
    current_music = sound
    return sound
end

function Audio.stopMusic()
    if current_music then
        current_music:stop()
        current_music = nil
    end
end

function Audio.stopAll()
    checkLove()
    for i = #playing, 1, -1 do
        playing[i]:stop()
        playing[i] = nil
    end
    Audio.stopMusic()
end

function Audio.setMasterVolume(v)
    checkLove()
    love.audio.setVolume(math.max(0, math.min(1, v or 1)))
end

function Audio.fadeIn(source, duration, target)
    if not source then return end
    target = target or 1
    source:setVolume(0)
    source:play()
    fades[#fades + 1] = {
        src = source, from = 0, to = target,
        elapsed = 0, duration = math.max(0.001, duration),
    }
end

function Audio.fadeOut(source, duration, on_complete)
    if not source then return end
    fades[#fades + 1] = {
        src = source,
        from = source:getVolume(),
        to = 0,
        elapsed = 0,
        duration = math.max(0.001, duration),
        on_complete = on_complete,
    }
end

function Audio.update(dt)
    for i = #fades, 1, -1 do
        local f = fades[i]
        f.elapsed = f.elapsed + dt
        local t = f.elapsed / f.duration
        if t >= 1 then t = 1 end
        f.src:setVolume(f.from + (f.to - f.from) * t)
        if t >= 1 then
            if f.to == 0 then
                f.src:stop()
                if f.on_complete then f.on_complete() end
            end
            table.remove(fades, i)
        end
    end
    for i = #playing, 1, -1 do
        if not playing[i]:isPlaying() then
            table.remove(playing, i)
        end
    end
end

return Audio
